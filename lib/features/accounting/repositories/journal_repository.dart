import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/features/accounting/models/journal_entry_model.dart';

/// Read-only data source for `accounting_transactions` and their lines.
///
/// The client never writes here. Every entry is produced by a transaction
/// function — a sale, a purchase, a payment, an expense — so a journal the
/// client could post to would be a way to write figures the source documents
/// do not support.
class JournalRepository extends SupabaseRepository<JournalEntryModel> {
  JournalRepository({super.client});

  @override
  String get table => DbTables.accountingTransactions;

  @override
  String get defaultSortColumn => 'transaction_date';

  @override
  String? get softDeleteColumn => null;

  /// Embeds each line with its account, so a row reads as a posting rather
  /// than as a list of identifiers.
  @override
  String get defaultSelect =>
      '*, users(id, name), '
      'accounting_entries(*, accounts(id, account_code, account_name))';

  @override
  JournalEntryModel fromJson(Map<String, Object?> json) =>
      JournalEntryModel.fromJson(json);
}
