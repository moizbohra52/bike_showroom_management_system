import 'package:bike_showroom_management_system/common/models/json_reader.dart';

/// A category an expense is booked under (`expense_categories`).
///
/// [accountCode] is the link to the chart of accounts: it decides which
/// expense account `create_expense_transaction` debits. A category without
/// one still records the expense but cannot post it to a specific account,
/// which is why the list flags it.
class ExpenseCategoryModel {
  const ExpenseCategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.accountCode,
    this.isActive = true,
    this.createdAt,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, Object?> json) {
    final JsonReader reader = JsonReader(json);
    return ExpenseCategoryModel(
      id: reader.requireString('id'),
      name: reader.string('name'),
      description: reader.stringOrNull('description'),
      accountCode: reader.stringOrNull('account_code'),
      isActive: reader.boolean('is_active', fallback: true),
      createdAt: reader.timestampOrNull('created_at'),
    );
  }

  final String id;
  final String name;
  final String? description;

  /// Chart-of-accounts code, e.g. `5101` for rent.
  final String? accountCode;

  final bool isActive;
  final DateTime? createdAt;

  /// Whether this category can be posted to a specific expense account.
  bool get isPostable => accountCode != null && accountCode!.isNotEmpty;

  Map<String, Object?> toJson() => buildWritePayload(<String, Object?>{
    'name': name.trim(),
    'description': description,
    'account_code': accountCode?.trim(),
    'is_active': isActive,
  });

  @override
  bool operator ==(Object other) =>
      other is ExpenseCategoryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ExpenseCategory($name)';
}
