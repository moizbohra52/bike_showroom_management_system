import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';

/// Remote data source for `inventory` — the physical units on a branch's floor.
class InventoryRepository extends SupabaseRepository<InventoryModel> {
  InventoryRepository({super.client});

  @override
  String get table => DbTables.inventory;

  @override
  String get defaultSortColumn => DbColumns.createdAt;

  /// Embeds the product (and its brand) plus the colour, so a row can be shown
  /// as "Honda Shine 125 - Pearl White" without three extra requests per page.
  @override
  String get defaultSelect =>
      '*, products(id, name, model, variant, category, brands(id, name)), '
      'product_colors(id, color_name, hex_code)';

  @override
  InventoryModel fromJson(Map<String, Object?> json) =>
      InventoryModel.fromJson(json);

  /// Reserves the next internal stock number for [showroomId].
  ///
  /// A gap here is harmless — unlike an invoice number, a stock code carries
  /// no statutory meaning, so burning one when an intake is abandoned costs
  /// nothing. Invoices go through an RPC that allocates the number inside the
  /// same transaction as the document precisely because that is not true of
  /// them.
  Future<String> nextStockCode(String showroomId) async {
    final Object? result = await rpc('next_document_number', <String, Object?>{
      'p_showroom_id': showroomId,
      'p_document_type': 'STOCK',
    });
    return result?.toString() ?? '';
  }

  /// Changes a unit's status through the `adjust_inventory` RPC.
  ///
  /// Deliberately not a plain UPDATE: the function validates the transition,
  /// writes the `stock_movements` row and records the reason in one
  /// transaction. Setting `status` directly would skip the validation and
  /// leave the audit trail to a trigger that cannot know *why* it moved.
  Future<void> adjustStatus({
    required String inventoryId,
    required InventoryStatus newStatus,
    required String reason,
  }) => rpc('adjust_inventory', <String, Object?>{
    'p_inventory_id': inventoryId,
    'p_new_status': newStatus.value,
    'p_reason': reason,
  });

  /// Units that can be attached to a sale, for a vehicle picker.
  Future<List<InventoryModel>> listAllocatable({
    required String showroomId,
    String? productId,
  }) => listAll(
    QueryParams(
      pageSize: 200,
      showroomId: showroomId,
      filters: <QueryFilter>[
        QueryFilter.inList(
          'status',
          InventoryStatus.values
              .where((InventoryStatus s) => s.isAllocatable)
              .map((InventoryStatus s) => s.value)
              .toList(growable: false),
        ),
        if (productId != null) QueryFilter.equals('product_id', productId),
      ],
      sorts: <QuerySort>[
        const QuerySort(
          column: 'stock_code',
          direction: SortDirection.ascending,
        ),
      ],
    ),
  );

  /// How many units sit in each status, for the summary strip above the list.
  ///
  /// [showroomId] must be whatever scope the **list** is using, not simply the
  /// session's active branch: a super admin browsing every branch would
  /// otherwise see tiles counting one branch above rows drawn from all of
  /// them. Passing null counts everything RLS lets the caller read, which is
  /// exactly what the unscoped list shows.
  ///
  /// Issued as one counting request per status rather than fetching the rows:
  /// a branch with two thousand units would otherwise transfer all of them to
  /// display six numbers.
  Future<Map<InventoryStatus, int>> statusCounts(String? showroomId) async {
    final Map<InventoryStatus, int> counts = <InventoryStatus, int>{};
    for (final InventoryStatus status in InventoryStatus.values) {
      counts[status] = await count(
        QueryParams(
          showroomId: showroomId,
          filters: <QueryFilter>[QueryFilter.equals('status', status.value)],
        ),
      );
    }
    return counts;
  }
}
