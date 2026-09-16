import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';

/// A row from `showrooms` — the tenancy boundary of the whole system.
class ShowroomModel implements SyncableModel {
  const ShowroomModel({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.gstNumber,
    this.panNumber,
    this.invoicePrefix,
    this.logoUrl,
    this.status = RecordStatus.active,
    this.settings = const <String, Object?>{},
    this.revision = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ShowroomModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return ShowroomModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      code: reader.string('code'),
      address: reader.stringOrNull('address'),
      city: reader.stringOrNull('city'),
      state: reader.stringOrNull('state'),
      pincode: reader.stringOrNull('pincode'),
      phone: reader.stringOrNull('phone'),
      email: reader.stringOrNull('email'),
      gstNumber: reader.stringOrNull('gst_number'),
      panNumber: reader.stringOrNull('pan_number'),
      invoicePrefix: reader.stringOrNull('invoice_prefix'),
      logoUrl: reader.stringOrNull('logo_url'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      settings: reader.jsonObject('settings'),
      revision: reader.integer('revision'),
      createdAt: reader.timestampOrNull('created_at'),
      updatedAt: reader.timestampOrNull('updated_at'),
    );
  }

  @override
  final String id;

  final String name;

  /// Short unique code. Used in generated document numbers, so it is immutable
  /// in practice once any document exists.
  final String code;

  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? gstNumber;
  final String? panNumber;

  /// Prefix for this showroom's invoice numbers, e.g. `MUM/INV`.
  final String? invoicePrefix;

  final String? logoUrl;
  final RecordStatus status;

  /// Per-showroom configuration held as `jsonb`, so a new toggle does not
  /// require a migration. Read through the typed getters below.
  final Map<String, Object?> settings;

  @override
  final int revision;

  @override
  final DateTime? updatedAt;

  final DateTime? createdAt;

  bool get isActive => status.isActive;

  /// Single-line address for an invoice header.
  String get formattedAddress {
    final List<String> parts = <String>[
      if (address != null && address!.isNotEmpty) address!,
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
      if (pincode != null && pincode!.isNotEmpty) pincode!,
    ];
    return parts.join(', ');
  }

  /// Initials for the avatar shown in the showroom switcher.
  String get initials {
    final List<String> words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) {
      return code.isNotEmpty ? code.substring(0, 1).toUpperCase() : '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  // ------------------------------------------------------- settings accessors

  T _setting<T>(String key, T fallback) {
    final Object? value = settings[key];
    if (value is T) {
      return value;
    }
    return fallback;
  }

  /// Whether product images served from this showroom get a watermark.
  bool get watermarkEnabled => _setting<bool>('watermark_enabled', false);

  /// Whether users may download original product images.
  bool get downloadRestricted => _setting<bool>('download_restricted', false);

  /// Preview-only mode hides full-resolution images entirely.
  bool get previewOnly => _setting<bool>('preview_only', false);

  /// Whether stock may go negative. Off by default, and the database enforces
  /// the same rule, so turning this on is a deliberate act.
  bool get allowNegativeStock => _setting<bool>('allow_negative_stock', false);

  /// Default GST rate applied to new products at this showroom.
  double get defaultTaxRate {
    final Object? value = settings['default_tax_rate'];
    if (value is num) {
      return value.toDouble();
    }
    return 18;
  }

  /// Discount percentage above which `sales.approve` is required.
  double get discountApprovalThreshold {
    final Object? value = settings['discount_approval_threshold'];
    if (value is num) {
      return value.toDouble();
    }
    return 5;
  }

  /// Terms printed at the foot of an invoice.
  String? get invoiceTerms => settings['invoice_terms'] as String?;

  int get lowStockThreshold {
    final Object? value = settings['low_stock_threshold'];
    if (value is num) {
      return value.toInt();
    }
    return 3;
  }

  @override
  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'name': name.trim(),
    'code': code.trim().toUpperCase(),
    'address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
    'phone': phone,
    'email': email,
    'gst_number': gstNumber?.toUpperCase(),
    'pan_number': panNumber?.toUpperCase(),
    'invoice_prefix': invoicePrefix?.toUpperCase(),
    'logo_url': logoUrl,
    'status': status.value,
    'settings': settings,
  });

  @override
  Map<String, Object?> toCacheJson() => <String, Object?>{
    'id': id,
    ...toJson(),
    'revision': revision,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  ShowroomModel copyWith({
    String? name,
    String? code,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? gstNumber,
    String? panNumber,
    String? invoicePrefix,
    String? logoUrl,
    RecordStatus? status,
    Map<String, Object?>? settings,
  }) => ShowroomModel(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    address: address ?? this.address,
    city: city ?? this.city,
    state: state ?? this.state,
    pincode: pincode ?? this.pincode,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    gstNumber: gstNumber ?? this.gstNumber,
    panNumber: panNumber ?? this.panNumber,
    invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    logoUrl: logoUrl ?? this.logoUrl,
    status: status ?? this.status,
    settings: settings ?? this.settings,
    revision: revision,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) => other is ShowroomModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Showroom($code - $name)';
}
