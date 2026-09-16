import 'package:bike_showroom_management_system/common/models/json_reader.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';

/// A ledger account (`accounts`).
///
/// Scoped per showroom, but the **codes are identical across branches** —
/// `provision_showroom_accounts` seeds the same chart for every new showroom.
/// That is what lets a group-wide report add branch figures together, and
/// what lets `resolve_account(showroom, '1003')` find the right receivable
/// account without the caller knowing its id.
class AccountModel {
  const AccountModel({
    required this.id,
    required this.showroomId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    this.parentAccountId,
    this.isSystemAccount = false,
    this.status = RecordStatus.active,
    this.createdAt,
  });

  factory AccountModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return AccountModel(
      id: reader.requireString('id'),
      showroomId: reader.string('showroom_id'),
      accountCode: reader.string('account_code'),
      accountName: reader.string('account_name'),
      accountType: AccountType.fromValue(reader.stringOrNull('account_type')),
      parentAccountId: reader.stringOrNull('parent_account_id'),
      isSystemAccount: reader.boolean('is_system_account'),
      status: RecordStatus.fromValue(reader.stringOrNull('status')),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String showroomId;

  /// e.g. `1003` receivable, `4001` vehicle sale revenue, `5101` rent.
  final String accountCode;

  final String accountName;
  final AccountType accountType;
  final String? parentAccountId;

  /// Seeded by the platform and referenced by name inside the transaction
  /// functions — renaming or retiring one would break a posting, which is why
  /// the UI marks them and refuses to edit them.
  final bool isSystemAccount;

  final RecordStatus status;
  final DateTime? createdAt;

  bool get isActive => status.isActive;

  String get label => '$accountCode - $accountName';

  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'account_code': accountCode.trim(),
    'account_name': accountName.trim(),
    'account_type': accountType.value,
    'parent_account_id': parentAccountId,
    'status': status.value,
  });

  @override
  bool operator ==(Object other) => other is AccountModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Account($label)';
}

/// One row of the `trial_balance` view.
///
/// The view aggregates `accounting_entries` per account, which is the report
/// that proves the books balance: summed across every account, total debits
/// must equal total credits.
class TrialBalanceRow {
  const TrialBalanceRow({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.balance = 0,
  });

  factory TrialBalanceRow.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return TrialBalanceRow(
      accountId: reader.string('account_id'),
      accountCode: reader.string('account_code'),
      accountName: reader.string('account_name'),
      accountType: AccountType.fromValue(reader.stringOrNull('account_type')),
      totalDebit: reader.money('total_debit'),
      totalCredit: reader.money('total_credit'),
      balance: reader.money('balance'),
    );
  }

  final String accountId;
  final String accountCode;
  final String accountName;
  final AccountType accountType;
  final double totalDebit;
  final double totalCredit;

  /// Signed by the account's natural side, as the view computes it.
  final double balance;

  bool get hasActivity => totalDebit != 0 || totalCredit != 0;

  String get label => '$accountCode - $accountName';

  @override
  String toString() => 'TrialBalanceRow($label)';
}
