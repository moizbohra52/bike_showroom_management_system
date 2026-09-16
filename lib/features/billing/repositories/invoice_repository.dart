import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';

/// Remote data source for `invoices`.
///
/// Read-only in practice. Invoices are raised by the sale and service
/// transactions, and `guard_invoice_immutability` refuses changes once one is
/// issued — so this repository deliberately exposes no create, and the base
/// class's `update` will be rejected by the server for anything but the few
/// columns that stay writable.
class InvoiceRepository extends SupabaseRepository<InvoiceModel> {
  InvoiceRepository({super.client});

  @override
  String get table => DbTables.invoices;

  @override
  String get defaultSortColumn => 'invoice_date';

  /// No `is_deleted` column: an invoice is cancelled, never deleted (§42).
  @override
  String? get softDeleteColumn => null;

  @override
  String get defaultSelect =>
      '*, customers(id, name, phone, gst_number, address), '
      'sales(id, sale_number)';

  /// Adds the lines, for the printable view.
  String get detailSelect => '$defaultSelect, invoice_items(*)';

  @override
  InvoiceModel fromJson(Map<String, Object?> json) =>
      InvoiceModel.fromJson(json);

  Future<InvoiceModel> getDetail(String id) =>
      getById(id, select: detailSelect);
}
