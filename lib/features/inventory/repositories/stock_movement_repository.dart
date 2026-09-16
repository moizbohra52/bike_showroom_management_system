import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/inventory/models/stock_movement_model.dart';

/// Read-only data source for `stock_movements`.
///
/// The table has no soft-delete column and the client never writes to it —
/// rows are produced by the `record_stock_movement` trigger. [softDeleteColumn]
/// is therefore null, which stops the base class adding an `is_deleted = false`
/// filter to a table that has no such column (PostgREST would reject the
/// query outright).
class StockMovementRepository extends SupabaseRepository<StockMovementModel> {
  StockMovementRepository({super.client});

  @override
  String get table => DbTables.stockMovements;

  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSortColumn => DbColumns.createdAt;

  /// Embeds the unit's stock code and the name of whoever caused the movement,
  /// so the history reads as a sentence rather than a pair of UUIDs.
  @override
  String get defaultSelect =>
      '*, inventory(id, stock_code, chassis_number), users(id, name)';

  @override
  StockMovementModel fromJson(Map<String, Object?> json) =>
      StockMovementModel.fromJson(json);
}
