import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';

/// Remote data source for `purchases`.
///
/// Both writes are RPCs: a purchase posts accounting entries, and receiving
/// one creates a row in `inventory` per physical machine. Neither is an
/// insert.
class PurchaseRepository extends SupabaseRepository<PurchaseModel> {
  PurchaseRepository({super.client});

  @override
  String get table => DbTables.purchases;

  @override
  String get defaultSortColumn => 'purchase_date';

  /// No `is_deleted` column: a purchase is cancelled, never deleted (§42).
  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSelect => '*, suppliers(id, name, gst_number)';

  /// Adds the lines, with each line's product and brand.
  String get detailSelect =>
      '$defaultSelect, '
      'purchase_items(*, products(id, name, variant, brands(id, name)))';

  @override
  PurchaseModel fromJson(Map<String, Object?> json) =>
      PurchaseModel.fromJson(json);

  Future<PurchaseModel> getDetail(String id) =>
      getById(id, select: detailSelect);

  /// Raises a purchase order through `create_purchase_transaction`.
  ///
  /// [payload]: `showroom_id`, `supplier_id`, `items` (each `product_id`,
  /// `quantity`, `unit_cost`, optional `tax_rate` / `description`), and
  /// optionally `supplier_invoice_no`, `purchase_date`, `discount`,
  /// `other_charges` and `notes`.
  ///
  /// Returns the new purchase's id. The order lands as ORDERED — no stock
  /// exists yet, because nothing has arrived.
  Future<String> createPurchase(Map<String, Object?> payload) async {
    final Object? result = await rpc(
      'create_purchase_transaction',
      <String, Object?>{'p_payload': payload},
    );
    final String? id = result?.toString();
    if (id == null || id.isEmpty) {
      throw ServerException(
        message: 'The purchase was not created. Please try again.',
      );
    }
    return id;
  }

  /// Takes a consignment into stock through `receive_purchase`.
  ///
  /// [payload]: `purchase_id` and `units` — one element per physical machine,
  /// each with `product_id`, `chassis_number`, `engine_number` and optionally
  /// `color_id`, `stock_code`, `manufacturing_date`, `model_year`,
  /// `purchase_price` and `location`.
  ///
  /// Returns how many units were created. Ordering and receiving are separate
  /// because they happen days apart, and because the chassis numbers are only
  /// known once the lorry arrives.
  Future<int> receivePurchase(Map<String, Object?> payload) async {
    final Object? result = await rpc('receive_purchase', <String, Object?>{
      'p_payload': payload,
    });
    return result is num ? result.toInt() : 0;
  }
}
