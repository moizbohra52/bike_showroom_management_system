import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';

/// One entry in a unit's movement history (`stock_movements`).
///
/// Written by the `record_stock_movement` trigger rather than by the client:
/// every status change on `inventory` produces a row automatically, so the
/// history cannot drift from what actually happened. The client only ever
/// reads this table, which is why the model has no write payload.
class StockMovementModel {
  const StockMovementModel({
    required this.id,
    required this.showroomId,
    required this.inventoryId,
    required this.movementType,
    this.fromStatus,
    this.toStatus,
    this.referenceType,
    this.referenceId,
    this.quantity = 1,
    this.notes,
    this.stockCode,
    this.createdAt,
    this.createdByName,
  });

  factory StockMovementModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader inventory = JsonReader(
      reader.objectOrNull('inventory') ?? const <String, Object?>{},
    );
    final JsonReader user = JsonReader(
      reader.objectOrNull('users') ?? const <String, Object?>{},
    );

    return StockMovementModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      inventoryId: reader.string('inventory_id'),
      movementType: StockMovementType.fromValue(
        reader.stringOrNull('movement_type'),
      ),
      // Not `InventoryStatus.fromValue`: that falls back to `available`, which
      // would turn a genuinely absent `from_status` on a unit's first movement
      // into a fabricated "Available -> Available" transition.
      fromStatus: statusOrNull(reader.stringOrNull('from_status')),
      toStatus: statusOrNull(reader.stringOrNull('to_status')),
      referenceType: reader.stringOrNull('reference_type'),
      referenceId: reader.stringOrNull('reference_id'),
      quantity: reader.integer('quantity', fallback: 1),
      notes: reader.stringOrNull('notes'),
      stockCode: inventory.stringOrNull('stock_code'),
      createdAt: reader.timestampOrNull('created_at'),
      createdByName: user.stringOrNull('name'),
    );
  }

  /// The status with this stored value, or null when the column was null.
  static InventoryStatus? statusOrNull(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final InventoryStatus status in InventoryStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }

  final String id;
  final String showroomId;
  final String inventoryId;
  final StockMovementType movementType;

  /// Null on the first movement, when the unit had no previous status.
  final InventoryStatus? fromStatus;
  final InventoryStatus? toStatus;

  /// What caused the movement — `SALE`, `TRANSFER`, `ADJUSTMENT`, and so on.
  final String? referenceType;
  final String? referenceId;

  final int quantity;
  final String? notes;

  /// Denormalised from an embedded `inventory(stock_code)`.
  final String? stockCode;

  final DateTime? createdAt;

  /// Denormalised from an embedded `users(name)`.
  final String? createdByName;

  /// `Available -> Reserved`, or just the destination on the first movement.
  String get transition {
    if (fromStatus == null) {
      return toStatus?.label ?? '-';
    }
    return '${fromStatus!.label} -> ${toStatus?.label ?? "-"}';
  }

  @override
  bool operator ==(Object other) =>
      other is StockMovementModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StockMovement(${movementType.value} $transition)';
}
