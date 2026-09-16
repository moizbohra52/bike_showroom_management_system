import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/service/models/service_item_model.dart';

/// A job card (`service_records`).
///
/// Unlike a sale, a job card **is** created by a plain insert: booking one
/// commits nothing financially, so there is nothing to make atomic. Money only
/// appears at the end, when `complete_service` totals the chargeable lines,
/// consumes a free-service entitlement if the visit qualifies, raises the
/// invoice, posts the revenue and schedules the next visit — all in one
/// transaction.
class ServiceRecordModel implements SyncableModel {
  const ServiceRecordModel({
    required this.id,
    required this.showroomId,
    required this.customerId,
    required this.vehicleId,
    required this.serviceNumber,
    required this.serviceDate,
    required this.odometerReading,
    this.customerName,
    this.customerPhone,
    this.vehicleRegistration,
    this.vehicleChassis,
    this.serviceAdvisorName,
    this.technicianName,
    this.bookingDate,
    this.deliveryDate,
    this.serviceType = ServiceType.paid,
    this.serviceStatus = ServiceStatus.booked,
    this.serviceAdvisorId,
    this.technicianId,
    this.complaint,
    this.inspectionNotes,
    this.workDone,
    this.nextServiceDate,
    this.nextServiceKm,
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.cancelledAt,
    this.items = const <ServiceItemModel>[],
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceRecordModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader customer = JsonReader(
      reader.objectOrNull('customers') ?? const <String, Object?>{},
    );
    final JsonReader vehicle = JsonReader(
      reader.objectOrNull('customer_vehicles') ?? const <String, Object?>{},
    );
    final JsonReader advisor = JsonReader(
      reader.objectOrNull('users') ?? const <String, Object?>{},
    );

    return ServiceRecordModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      customerId: reader.string('customer_id'),
      vehicleId: reader.string('vehicle_id'),
      serviceNumber: reader.string('service_number'),
      serviceDate: reader.dateOrNull('service_date') ?? DateTime.now(),
      odometerReading: reader.integer('odometer_reading'),
      customerName: customer.stringOrNull('name'),
      customerPhone: customer.stringOrNull('phone'),
      vehicleRegistration: vehicle.stringOrNull('registration_number'),
      vehicleChassis: vehicle.stringOrNull('chassis_number'),
      serviceAdvisorName: advisor.stringOrNull('name'),
      bookingDate: reader.dateOrNull('booking_date'),
      deliveryDate: reader.dateOrNull('delivery_date'),
      serviceType: ServiceType.fromValue(reader.stringOrNull('service_type')),
      serviceStatus: ServiceStatus.fromValue(
        reader.stringOrNull('service_status'),
      ),
      serviceAdvisorId: reader.stringOrNull('service_advisor_id'),
      technicianId: reader.stringOrNull('technician_id'),
      complaint: reader.stringOrNull('complaint'),
      inspectionNotes: reader.stringOrNull('inspection_notes'),
      workDone: reader.stringOrNull('work_done'),
      nextServiceDate: reader.dateOrNull('next_service_date'),
      nextServiceKm: reader.intOrNull('next_service_km'),
      subtotal: reader.money('subtotal'),
      discount: reader.money('discount'),
      taxAmount: reader.money('tax_amount'),
      totalAmount: reader.money('total_amount'),
      paidAmount: reader.money('paid_amount'),
      outstandingAmount: reader.money('outstanding_amount'),
      cancelledAt: reader.timestampOrNull('cancelled_at'),
      items: reader.list('service_items', ServiceItemModel.fromJson),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String showroomId;
  final String customerId;
  final String vehicleId;

  /// From `next_document_number(..., 'SERVICE')`.
  final String serviceNumber;

  final DateTime serviceDate;

  /// Kilometres on arrival. `guard_odometer_monotonic` refuses a reading below
  /// the vehicle's last, because a falling odometer is a typo or tampering.
  final int odometerReading;

  // Denormalised from embedded relations.
  final String? customerName;
  final String? customerPhone;
  final String? vehicleRegistration;
  final String? vehicleChassis;
  final String? serviceAdvisorName;
  final String? technicianName;

  final DateTime? bookingDate;
  final DateTime? deliveryDate;
  final ServiceType serviceType;
  final ServiceStatus serviceStatus;
  final String? serviceAdvisorId;
  final String? technicianId;

  /// What the customer reported.
  final String? complaint;

  final String? inspectionNotes;

  /// What the workshop actually did — printed on the job card.
  final String? workDone;

  final DateTime? nextServiceDate;
  final int? nextServiceKm;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final DateTime? cancelledAt;

  final List<ServiceItemModel> items;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isCompleted =>
      serviceStatus == ServiceStatus.completed ||
      serviceStatus == ServiceStatus.delivered;

  bool get isCancelled => serviceStatus == ServiceStatus.cancelled;

  /// Whether the job card can still be completed.
  ///
  /// Mirrors `complete_service`, which refuses anything already completed,
  /// delivered or cancelled.
  bool get canComplete => !isCompleted && !isCancelled;

  /// Whether lines can still be added.
  bool get canEditItems => canComplete;

  bool get isFullyPaid => outstandingAmount <= 0.01;

  /// Lines that will actually be billed. Warranty and free-service work is
  /// recorded but never charged.
  List<ServiceItemModel> get chargeableItems => items
      .where((ServiceItemModel i) => i.isChargeable)
      .toList(growable: false);

  /// Work absorbed by the showroom under warranty or a free service.
  double get absorbedValue => items
      .where((ServiceItemModel i) => !i.isChargeable)
      .fold<double>(0, (double sum, ServiceItemModel i) => sum + i.grossAmount);

  /// What the chargeable lines come to before the document discount. A
  /// preview: `complete_service` recomputes it from the rows themselves.
  double get chargeableSubtotal => chargeableItems.fold<double>(
    0,
    (double sum, ServiceItemModel i) => sum + i.taxableAmount,
  );

  /// `MP09AB1234` or, for an unregistered vehicle, its chassis number.
  String get vehicleLabel =>
      vehicleRegistration != null && vehicleRegistration!.isNotEmpty
      ? vehicleRegistration!
      : (vehicleChassis ?? 'Unknown vehicle');

  String get formattedTotal => MoneyUtil.format(totalAmount);

  String get formattedOutstanding => MoneyUtil.format(outstandingAmount);

  String get formattedDate => DateUtil.format(serviceDate);

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'customer_id': customerId,
    'vehicle_id': vehicleId,
    'service_number': serviceNumber,
    'booking_date': DateUtil.toIsoDateOrNull(bookingDate),
    'service_date': DateUtil.toIsoDateOrNull(serviceDate),
    'odometer_reading': odometerReading,
    'service_type': serviceType.value,
    'service_status': serviceStatus.value,
    'service_advisor_id': serviceAdvisorId,
    'technician_id': technicianId,
    'complaint': complaint,
    'inspection_notes': inspectionNotes,
    // Amounts are server-owned: `complete_service` computes them from the
    // lines, so sending them would let a stale form disagree with the ledger.
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    'showroom_id': showroomId,
    'customer_id': customerId,
    'vehicle_id': vehicleId,
    'service_number': serviceNumber,
    'service_date': DateUtil.toIsoDateOrNull(serviceDate),
    'service_status': serviceStatus.value,
    'total_amount': totalAmount,
    'outstanding_amount': outstandingAmount,
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is ServiceRecordModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ServiceRecord($serviceNumber $vehicleLabel)';
}

/// What `complete_service` returns.
///
/// Matches the function's `jsonb_build_object` exactly: it reports the invoice
/// it raised (if any) and the next visit it scheduled. It does **not** return
/// an invoice number, so the caller looks that up if it needs to show one.
class ServiceCompletionResult {
  const ServiceCompletionResult({
    required this.serviceId,
    this.invoiceId,
    this.totalAmount = 0,
    this.nextServiceDate,
    this.nextServiceKm,
  });

  factory ServiceCompletionResult.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return ServiceCompletionResult(
      serviceId: reader.requireString('service_id'),
      invoiceId: reader.stringOrNull('invoice_id'),
      totalAmount: reader.money('total_amount'),
      nextServiceDate: reader.dateOrNull('next_service_date'),
      nextServiceKm: reader.intOrNull('next_service_km'),
    );
  }

  final String serviceId;

  /// Null when nothing was chargeable — a free service or warranty job raises
  /// no invoice at all rather than a zero-value one.
  final String? invoiceId;

  final double totalAmount;

  /// Six months and 5,000 km on, whichever the customer reaches first. Written
  /// to both the job card and the vehicle by the same transaction.
  final DateTime? nextServiceDate;

  final int? nextServiceKm;

  bool get raisedInvoice => invoiceId != null;

  @override
  String toString() => 'ServiceCompletionResult($serviceId)';
}
