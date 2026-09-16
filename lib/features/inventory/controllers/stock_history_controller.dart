import 'package:bike_showroom_management_system/common/controllers/list_controller.dart';
import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/models/stock_movement_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/stock_movement_repository.dart';

/// Movement history, either for the whole branch or for one unit.
///
/// Passing a [unit] narrows it to that machine's own timeline, which is what
/// the "History" action on an inventory row opens; without one it is the
/// branch-wide stock ledger.
class StockHistoryController extends ListController<StockMovementModel> {
  StockHistoryController({
    required StockMovementRepository repository,
    this.unit,
  }) : super(
         repository: repository,
         // `stock_movements` holds no searchable text of its own — the stock
         // code lives on the embedded `inventory` row, and PostgREST cannot
         // filter an `or()` across an embedded table. Filtering is by unit and
         // by date instead, which is how this screen is actually used.
         searchColumns: const <String>[],
       );

  /// The unit being inspected, or null for the branch-wide ledger.
  final InventoryModel? unit;

  String get title =>
      unit == null ? 'Stock History' : 'History - ${unit!.stockCode}';

  @override
  void onInit() {
    final InventoryModel? source = unit;
    if (source != null) {
      params.value = params.value.withFilter(
        QueryFilter.equals('inventory_id', source.id),
      );
    }
    // After the filter, so the first load already carries it. `super.onInit()`
    // is what issues that load.
    super.onInit();
  }
}
