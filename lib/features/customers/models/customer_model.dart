import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';

/// A row from `customers`.
///
/// Scoped to a showroom. Two branches of the same group each keep their own
/// customer record even for the same person: the relationship, the vehicles
/// and the service history belong to the branch that sold and services them,
/// and merging them would mean one branch's staff reading another's customer
/// list, which is exactly what the tenancy rules forbid.
class CustomerModel implements SyncableModel {
  const CustomerModel({
    required this.id,
    required this.showroomId,
    required this.customerCode,
    required this.name,
    required this.phone,
    this.alternatePhone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.dateOfBirth,
    this.gstNumber,
    this.panNumber,
    this.customerType = CustomerType.individual,
    this.notes,
    this.status = RecordStatus.active,
    this.vehicleCount = 0,
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomerModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return CustomerModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      customerCode: reader.string('customer_code'),
      name: reader.string('name'),
      phone: reader.string('phone'),
      alternatePhone: reader.stringOrNull('alternate_phone'),
      email: reader.stringOrNull('email'),
      address: reader.stringOrNull('address'),
      city: reader.stringOrNull('city'),
      state: reader.stringOrNull('state'),
      pincode: reader.stringOrNull('pincode'),
      dateOfBirth: reader.dateOrNull('date_of_birth'),
      gstNumber: reader.stringOrNull('gst_number'),
      panNumber: reader.stringOrNull('pan_number'),
      customerType: CustomerType.fromValue(
        reader.stringOrNull('customer_type'),
      ),
      notes: reader.stringOrNull('notes'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      // Present when the caller embedded `customer_vehicles(count)`.
      vehicleCount: _embeddedCount(reader, 'customer_vehicles'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  /// PostgREST returns an aggregate embed as `[{"count": 3}]`.
  static int _embeddedCount(JsonReader reader, String key) {
    final List<Map<String, Object?>> rows = reader.objectList(key);
    if (rows.isEmpty) {
      return 0;
    }
    return JsonReader(rows.first).integer('count');
  }

  @override
  final String id;

  final String showroomId;

  /// Branch-scoped customer number from
  /// `next_document_number(..., 'CUSTOMER')`.
  final String customerCode;

  final String name;

  /// Ten digits starting 6-9; normalised server-side by
  /// `normalise_customer_phone` so `+91 98765 43210` and `9876543210` are the
  /// same customer rather than two.
  final String phone;

  final String? alternatePhone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final DateTime? dateOfBirth;
  final String? gstNumber;
  final String? panNumber;
  final CustomerType customerType;
  final String? notes;
  final RecordStatus status;

  /// How many vehicles this customer owns, when the query asked for it.
  final int vehicleCount;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status.isActive;

  /// A corporate buyer needs a GST number on the invoice; an individual does
  /// not. The form uses this to decide what to insist on.
  bool get requiresGst => customerType != CustomerType.individual;

  String get formattedAddress {
    final List<String> parts = <String>[
      if (address != null && address!.isNotEmpty) address!,
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
      if (pincode != null && pincode!.isNotEmpty) pincode!,
    ];
    return parts.join(', ');
  }

  /// Birthday greetings are a standing showroom habit, and the reminder
  /// engine needs the date in the current year to schedule one.
  bool get hasBirthdayThisMonth {
    final DateTime? dob = dateOfBirth;
    return dob != null && dob.month == DateTime.now().month;
  }

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'showroom_id': showroomId,
    'customer_code': customerCode,
    'name': name.trim(),
    'phone': phone.trim(),
    'alternate_phone': alternatePhone,
    'email': email?.trim().toLowerCase(),
    'address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
    'date_of_birth': DateUtil.toIsoDateOrNull(dateOfBirth),
    'gst_number': gstNumber?.toUpperCase(),
    'pan_number': panNumber?.toUpperCase(),
    'customer_type': customerType.value,
    'notes': notes,
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

  CustomerModel copyWith({
    String? name,
    String? phone,
    String? alternatePhone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    DateTime? dateOfBirth,
    String? gstNumber,
    String? panNumber,
    CustomerType? customerType,
    String? notes,
    RecordStatus? status,
  }) => CustomerModel(
    id: id,
    showroomId: showroomId,
    customerCode: customerCode,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    alternatePhone: alternatePhone ?? this.alternatePhone,
    email: email ?? this.email,
    address: address ?? this.address,
    city: city ?? this.city,
    state: state ?? this.state,
    pincode: pincode ?? this.pincode,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    gstNumber: gstNumber ?? this.gstNumber,
    panNumber: panNumber ?? this.panNumber,
    customerType: customerType ?? this.customerType,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    vehicleCount: vehicleCount,
    revision: revision,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) => other is CustomerModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Customer($customerCode $name)';
}
