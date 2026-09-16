/// Product, inventory and stock-movement enumerations.
library;

/// Fuel system of a bike variant.
enum FuelType {
  petrol('PETROL', 'Petrol'),
  electric('ELECTRIC', 'Electric'),
  hybrid('HYBRID', 'Hybrid'),
  cng('CNG', 'CNG');

  const FuelType(this.value, this.label);

  final String value;
  final String label;

  static FuelType fromValue(String? value) => FuelType.values.firstWhere(
    (FuelType type) => type.value == value,
    orElse: () => FuelType.petrol,
  );

  /// Electric vehicles carry a motor number rather than an engine number. The
  /// column is shared, but the validation pattern differs.
  bool get hasCombustionEngine => this != FuelType.electric;
}

/// Transmission of a bike variant.
enum TransmissionType {
  manual('MANUAL', 'Manual'),
  automatic('AUTOMATIC', 'Automatic'),
  cvt('CVT', 'CVT'),
  semiAutomatic('SEMI_AUTOMATIC', 'Semi Automatic');

  const TransmissionType(this.value, this.label);

  final String value;
  final String label;

  static TransmissionType fromValue(String? value) =>
      TransmissionType.values.firstWhere(
        (TransmissionType type) => type.value == value,
        orElse: () => TransmissionType.manual,
      );
}

/// Product category. A showroom sells more than bikes, so accessories and
/// spare parts share the `products` table and are separated by category.
enum ProductCategory {
  motorcycle('MOTORCYCLE', 'Motorcycle'),
  scooter('SCOOTER', 'Scooter'),
  moped('MOPED', 'Moped'),
  electricTwoWheeler('ELECTRIC_TWO_WHEELER', 'Electric Two Wheeler'),
  accessory('ACCESSORY', 'Accessory'),
  sparePart('SPARE_PART', 'Spare Part'),
  lubricant('LUBRICANT', 'Lubricant');

  const ProductCategory(this.value, this.label);

  final String value;
  final String label;

  static ProductCategory fromValue(String? value) =>
      ProductCategory.values.firstWhere(
        (ProductCategory category) => category.value == value,
        orElse: () => ProductCategory.motorcycle,
      );

  /// Only serialised vehicles occupy a row in `inventory` with a unique chassis
  /// and engine number. Accessories and parts are tracked by quantity instead.
  bool get isSerialisedVehicle =>
      this == ProductCategory.motorcycle ||
      this == ProductCategory.scooter ||
      this == ProductCategory.moped ||
      this == ProductCategory.electricTwoWheeler;
}

/// Status of a single physical bike held in stock.
enum InventoryStatus {
  available('AVAILABLE', 'Available'),
  reserved('RESERVED', 'Reserved'),
  sold('SOLD', 'Sold'),
  demo('DEMO', 'Demo'),
  damaged('DAMAGED', 'Damaged'),
  inTransit('IN_TRANSIT', 'In Transit'),
  returned('RETURNED', 'Returned');

  const InventoryStatus(this.value, this.label);

  final String value;
  final String label;

  static InventoryStatus fromValue(String? value) =>
      InventoryStatus.values.firstWhere(
        (InventoryStatus status) => status.value == value,
        orElse: () => InventoryStatus.available,
      );

  /// A unit may only be attached to a new sale from these states. The identical
  /// rule is enforced server-side inside `create_sale_transaction()`.
  bool get isAllocatable =>
      this == InventoryStatus.available ||
      this == InventoryStatus.reserved ||
      this == InventoryStatus.demo;

  /// Whether the unit counts towards on-hand stock on the dashboard.
  bool get countsAsStock => isAllocatable || this == InventoryStatus.inTransit;

  /// Terminal states that must never be silently reverted by a sync.
  bool get isTerminal => this == InventoryStatus.sold;
}

/// Direction and reason of a stock movement, recorded in `stock_movements`.
enum StockMovementType {
  stockIn('STOCK_IN', 'Stock In'),
  stockOut('STOCK_OUT', 'Stock Out'),
  transferOut('TRANSFER_OUT', 'Transfer Out'),
  transferIn('TRANSFER_IN', 'Transfer In'),
  adjustment('ADJUSTMENT', 'Adjustment'),
  reservation('RESERVATION', 'Reservation'),
  release('RELEASE', 'Release'),
  saleAllocation('SALE_ALLOCATION', 'Sale Allocation'),
  saleReversal('SALE_REVERSAL', 'Sale Reversal'),
  damage('DAMAGE', 'Damage'),
  returnToSupplier('RETURN_TO_SUPPLIER', 'Return To Supplier');

  const StockMovementType(this.value, this.label);

  final String value;
  final String label;

  static StockMovementType fromValue(String? value) =>
      StockMovementType.values.firstWhere(
        (StockMovementType type) => type.value == value,
        orElse: () => StockMovementType.adjustment,
      );
}

/// Status of an inter-showroom stock transfer.
enum StockTransferStatus {
  pending('PENDING', 'Pending'),
  inTransit('IN_TRANSIT', 'In Transit'),
  received('RECEIVED', 'Received'),
  cancelled('CANCELLED', 'Cancelled');

  const StockTransferStatus(this.value, this.label);

  final String value;
  final String label;

  static StockTransferStatus fromValue(String? value) =>
      StockTransferStatus.values.firstWhere(
        (StockTransferStatus status) => status.value == value,
        orElse: () => StockTransferStatus.pending,
      );

  bool get isOpen =>
      this == StockTransferStatus.pending ||
      this == StockTransferStatus.inTransit;
}

/// Lifecycle of a customer-owned vehicle.
enum VehicleStatus {
  active('ACTIVE', 'Active'),
  resold('RESOLD', 'Resold'),
  scrapped('SCRAPPED', 'Scrapped'),
  transferred('TRANSFERRED', 'Transferred'),
  stolen('STOLEN', 'Stolen');

  const VehicleStatus(this.value, this.label);

  final String value;
  final String label;

  static VehicleStatus fromValue(String? value) =>
      VehicleStatus.values.firstWhere(
        (VehicleStatus status) => status.value == value,
        orElse: () => VehicleStatus.active,
      );

  /// Only active vehicles are eligible for service booking and warranty claims.
  bool get isServiceable => this == VehicleStatus.active;
}
