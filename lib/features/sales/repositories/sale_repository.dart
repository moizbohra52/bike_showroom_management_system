import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';

/// Remote data source for `sales`.
///
/// Creation and cancellation both go through RPCs rather than through the
/// base class's [create]/[delete]; see [createSale] for why.
class SaleRepository extends SupabaseRepository<SaleModel> {
  SaleRepository({super.client});

  @override
  String get table => DbTables.sales;

  @override
  String get defaultSortColumn => 'sale_date';

  /// `sales` has no `is_deleted` column — a sale is cancelled, never deleted
  /// (§42). Leaving the base class's default here would add an
  /// `is_deleted = false` filter to a table without the column and every
  /// query would fail.
  @override
  String? get softDeleteColumn => null;

  /// The salesperson embed **must** name its foreign key.
  ///
  /// `sales` points at `users` four times — salesperson, created_by,
  /// updated_by, cancelled_by — so a bare `users(...)` is ambiguous and
  /// PostgREST rejects the whole request with PGRST201 rather than guessing.
  @override
  String get defaultSelect =>
      '*, customers(id, name, phone), '
      'users!sales_salesperson_id_fkey(id, name), '
      'invoices(id, invoice_number, status)';

  /// Adds the line items. Used by the details screen; the list does not need
  /// them and fetching them per row would multiply the payload.
  String get detailSelect =>
      '$defaultSelect, '
      'sale_items(*, products(id, name, variant), '
      'inventory(id, stock_code, chassis_number))';

  @override
  SaleModel fromJson(Map<String, Object?> json) => SaleModel.fromJson(json);

  Future<SaleModel> getDetail(String id) => getById(id, select: detailSelect);

  /// Creates a sale through `create_sale_transaction`.
  ///
  /// Not an insert. The function prices every line from the catalogue (so a
  /// tampered form cannot set its own price), locks each unit `FOR UPDATE`
  /// (so two salespeople cannot sell the same bike), allocates the stock,
  /// registers the customer's vehicle, raises the invoice, posts the balanced
  /// accounting entries, records any down payment and builds the loan
  /// schedule — atomically. An insert from here would produce a sale with no
  /// invoice and no ledger entry the first time the next step failed.
  ///
  /// [payload] keys, matching the function's contract:
  /// `showroom_id`, `customer_id`, `items` (each `inventory_id`, optional
  /// `quantity` / `unit_price` / `discount` / `tax_rate`), and optionally
  /// `sale_date`, `sale_type`, `discount`, `other_charges`, `paid_amount`,
  /// `payment_method`, `payment_reference`, `delivery_date`, `notes`,
  /// `salesperson_id` and `loan`.
  Future<SaleTransactionResult> createSale(Map<String, Object?> payload) async {
    final Object? result = await rpc(
      'create_sale_transaction',
      <String, Object?>{'p_payload': payload},
    );
    if (result is! Map) {
      throw ServerException(
        message: 'The sale was not created. Please try again.',
      );
    }
    return SaleTransactionResult.fromJson(Map<String, Object?>.from(result));
  }

  /// Cancels a sale through `cancel_sale_transaction`.
  ///
  /// The function returns the stock to the floor, reverses the accounting
  /// entries and voids the invoice. Setting `status = 'CANCELLED'` directly
  /// would leave the unit marked SOLD and the ledger claiming revenue that no
  /// longer exists.
  Future<void> cancelSale({required String saleId, required String reason}) =>
      rpc('cancel_sale_transaction', <String, Object?>{
        'p_sale_id': saleId,
        'p_reason': reason,
      });
}
