import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';

/// One posting line (`accounting_entries`).
class JournalLineModel {
  const JournalLineModel({
    required this.id,
    required this.transactionId,
    required this.accountId,
    this.accountCode,
    this.accountName,
    this.debit = 0,
    this.credit = 0,
    this.description,
  });

  factory JournalLineModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader account = JsonReader(
      reader.objectOrNull('accounts') ?? const <String, Object?>{},
    );
    return JournalLineModel(
      id: reader.requireString('id'),
      transactionId: reader.string('transaction_id'),
      accountId: reader.string('account_id'),
      accountCode: account.stringOrNull('account_code'),
      accountName: account.stringOrNull('account_name'),
      debit: reader.money('debit'),
      credit: reader.money('credit'),
      description: reader.stringOrNull('description'),
    );
  }

  final String id;
  final String transactionId;
  final String accountId;
  final String? accountCode;
  final String? accountName;
  final double debit;
  final double credit;
  final String? description;

  bool get isDebit => debit > 0;

  String get accountLabel =>
      accountCode == null ? accountId : '$accountCode - ${accountName ?? ""}';

  String get formattedAmount => MoneyUtil.format(isDebit ? debit : credit);

  @override
  bool operator ==(Object other) => other is JournalLineModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'JournalLine($accountLabel $formattedAmount)';
}

/// One journal entry (`accounting_transactions`) with its lines.
///
/// Written only by the transaction functions — a sale, a purchase, a payment,
/// an expense. Nothing here is client-authored, and the
/// `assert_ledger_balanced` constraint trigger refuses any entry whose debits
/// and credits differ by more than a paisa.
class JournalEntryModel {
  const JournalEntryModel({
    required this.id,
    required this.showroomId,
    required this.transactionDate,
    required this.referenceType,
    required this.description,
    this.referenceId,
    this.reversesTransactionId,
    this.isReversed = false,
    this.createdByName,
    this.lines = const <JournalLineModel>[],
    this.createdAt,
  });

  factory JournalEntryModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    final JsonReader author = JsonReader(
      reader.objectOrNull('users') ?? const <String, Object?>{},
    );
    return JournalEntryModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      transactionDate: reader.dateOrNull('transaction_date') ?? DateTime.now(),
      referenceType: AccountingReferenceType.fromValue(
        reader.stringOrNull('reference_type'),
      ),
      description: reader.string('description'),
      referenceId: reader.stringOrNull('reference_id'),
      reversesTransactionId: reader.stringOrNull('reverses_transaction_id'),
      isReversed: reader.boolean('is_reversed'),
      createdByName: author.stringOrNull('name'),
      lines: reader.list('accounting_entries', JournalLineModel.fromJson),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String showroomId;
  final DateTime transactionDate;

  /// What produced this entry — SALE, PURCHASE, PAYMENT, EXPENSE, and so on.
  final AccountingReferenceType referenceType;

  final String description;
  final String? referenceId;

  /// Set on the contra entry that reverses an earlier one.
  final String? reversesTransactionId;

  final bool isReversed;
  final String? createdByName;
  final List<JournalLineModel> lines;
  final DateTime? createdAt;

  bool get isReversal => reversesTransactionId != null;

  double get totalDebit =>
      lines.fold<double>(0, (double sum, JournalLineModel l) => sum + l.debit);

  double get totalCredit =>
      lines.fold<double>(0, (double sum, JournalLineModel l) => sum + l.credit);

  /// Whether this entry's own lines balance.
  ///
  /// Always true for data the server wrote — the constraint trigger guarantees
  /// it. Shown anyway, because a journal that cannot demonstrate it is not
  /// much use as a journal.
  bool get isBalanced => (totalDebit - totalCredit).abs() <= 0.01;

  String get formattedDate => DateUtil.format(transactionDate);

  String get formattedTotal => MoneyUtil.format(totalDebit);

  @override
  bool operator ==(Object other) =>
      other is JournalEntryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'JournalEntry(${referenceType.value} $formattedTotal)';
}
