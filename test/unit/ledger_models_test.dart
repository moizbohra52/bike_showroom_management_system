import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/accounting/models/account_model.dart';
import 'package:bike_showroom_management_system/features/accounting/models/journal_entry_model.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_category_model.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_model.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PurchaseModel', () {
    Map<String, Object?> row({String status = 'ORDERED', int quantity = 2}) =>
        <String, Object?>{
          'id': 'p1',
          'showroom_id': 'sr1',
          'supplier_id': 'su1',
          'purchase_number': 'SMI/PUR/2627/00001',
          'purchase_date': '2026-09-16',
          'supplier_invoice_no': 'SUPINV-9001',
          'subtotal': 150000,
          'discount': 0,
          'tax_amount': 42000,
          'other_charges': 2000,
          'total_amount': 194000,
          'paid_amount': 0,
          'outstanding_amount': 194000,
          'status': status,
          'suppliers': <String, Object?>{
            'name': 'Honda Distributors MP',
            'gst_number': '23AAACH1234A1Z7',
          },
          'purchase_items': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'i1',
              'purchase_id': 'p1',
              'product_id': 'prod1',
              'quantity': quantity,
              'unit_cost': 75000,
              'tax_rate': 28,
              'tax_amount': 42000,
              'total_amount': 192000,
              'products': <String, Object?>{
                'name': 'Shine 125',
                'brands': <String, Object?>{'name': 'Honda'},
              },
            },
          ],
        };

    test('reads the supplier and its lines', () {
      final PurchaseModel purchase = PurchaseModel.fromJson(row());
      expect(purchase.supplierName, 'Honda Distributors MP');
      expect(purchase.supplierGstNumber, isNotNull);
      expect(purchase.items, hasLength(1));
      expect(purchase.items.single.label, 'Honda Shine 125');
    });

    test('an ordered consignment has not been received', () {
      final PurchaseModel purchase = PurchaseModel.fromJson(row());
      expect(purchase.isReceived, isFalse);
      expect(purchase.canReceive, isTrue);
      // `inventory_id` is null until receipt, which is what says a line is
      // still on order rather than on the floor.
      expect(purchase.items.single.isReceived, isFalse);
    });

    test('a received consignment cannot be received again', () {
      // `receive_purchase` refuses a second attempt, so offering the action
      // would only produce an error.
      final PurchaseModel purchase = PurchaseModel.fromJson(
        row(status: 'RECEIVED'),
      );
      expect(purchase.isReceived, isTrue);
      expect(purchase.canReceive, isFalse);
    });

    test('a cancelled order cannot be received', () {
      expect(
        PurchaseModel.fromJson(row(status: 'CANCELLED')).canReceive,
        isFalse,
      );
    });

    test('expected unit count sums the line quantities', () {
      // This is how many chassis/engine pairs the receiving screen must ask
      // for, and how many `inventory` rows the RPC will create.
      expect(PurchaseModel.fromJson(row()).expectedUnitCount, 2);
      expect(PurchaseModel.fromJson(row(quantity: 5)).expectedUnitCount, 5);
    });

    test('the write payload keeps out the server-owned columns', () {
      final Map<String, Object?> payload = PurchaseModel.fromJson(
        row(),
      ).toJson();
      for (final String key in <String>[
        'total_amount',
        'outstanding_amount',
        'status',
        'purchase_number',
      ]) {
        expect(payload.containsKey(key), isFalse, reason: key);
      }
      expect(payload['supplier_invoice_no'], 'SUPINV-9001');
    });
  });

  group('ExpenseCategoryModel', () {
    test('a category without an account code is not postable', () {
      // It records the expense but cannot direct it at a specific expense
      // account, which the form warns about rather than discovering at month
      // end.
      final ExpenseCategoryModel unmapped = ExpenseCategoryModel.fromJson(
        <String, Object?>{'id': 'c1', 'name': 'Sundries'},
      );
      expect(unmapped.isPostable, isFalse);

      final ExpenseCategoryModel mapped = ExpenseCategoryModel.fromJson(
        <String, Object?>{'id': 'c2', 'name': 'Rent', 'account_code': '5101'},
      );
      expect(mapped.isPostable, isTrue);
    });
  });

  group('ExpenseModel', () {
    Map<String, Object?> row({
      String status = 'PENDING',
      String createdBy = 'user-a',
      String method = 'BANK_TRANSFER',
    }) => <String, Object?>{
      'id': 'e1',
      'showroom_id': 'sr1',
      'category_id': 'c1',
      'expense_number': 'SMI/EXP/2627/00001',
      'expense_date': '2026-09-16',
      'amount': 45000,
      'tax_amount': 8100,
      'total_amount': 53100,
      'payment_method': method,
      'status': status,
      'created_by': createdBy,
      'expense_categories': <String, Object?>{
        'name': 'Rent',
        'account_code': '5101',
      },
      'users': <String, Object?>{'name': 'Asha'},
    };

    test('reads the approver through the FK-hinted embed', () {
      // `expenses` references `users` three times, so the embed must name
      // expenses_approved_by_fkey or PostgREST refuses the request.
      expect(ExpenseModel.fromJson(row()).approvedByName, 'Asha');
      expect(ExpenseModel.fromJson(row()).categoryAccountCode, '5101');
    });

    test('someone else may decide a pending expense', () {
      expect(ExpenseModel.fromJson(row()).canBeDecidedBy('user-b'), isTrue);
    });

    test('the person who recorded it may not decide it', () {
      // Separation of duties, enforced server-side by `approve_expense`.
      expect(ExpenseModel.fromJson(row()).canBeDecidedBy('user-a'), isFalse);
    });

    test('a super admin is exempt, matching the SQL guard', () {
      // `approve_expense` exempts a super admin explicitly. A stricter client
      // would hide the button from the only account allowed to use it on a
      // single-administrator installation.
      expect(
        ExpenseModel.fromJson(
          row(),
        ).canBeDecidedBy('user-a', isSuperAdmin: true),
        isTrue,
      );
    });

    test('a decided expense is not decidable again', () {
      for (final String status in <String>['APPROVED', 'REJECTED', 'PAID']) {
        expect(
          ExpenseModel.fromJson(
            row(status: status),
          ).canBeDecidedBy('user-b', isSuperAdmin: true),
          isFalse,
          reason: status,
        );
      }
    });

    test('a non-cash tender needs a reference', () {
      expect(ExpenseModel.fromJson(row()).requiresReference, isTrue);
      expect(
        ExpenseModel.fromJson(row(method: 'CASH')).requiresReference,
        isFalse,
      );
    });
  });

  group('AccountModel', () {
    test('labels an account by code and name', () {
      final AccountModel account = AccountModel.fromJson(<String, Object?>{
        'id': 'a1',
        'showroom_id': 'sr1',
        'account_code': '1004',
        'account_name': 'Inventory',
        'account_type': 'ASSET',
        'is_system_account': true,
      });
      expect(account.label, '1004 - Inventory');
      expect(account.accountType, AccountType.asset);
      // System accounts are referenced by code inside the transaction
      // functions, so the UI marks them rather than offering an edit.
      expect(account.isSystemAccount, isTrue);
    });
  });

  group('TrialBalanceRow', () {
    TrialBalanceRow row({double debit = 0, double credit = 0}) =>
        TrialBalanceRow.fromJson(<String, Object?>{
          'account_id': 'a1',
          'account_code': '1004',
          'account_name': 'Inventory',
          'account_type': 'ASSET',
          'total_debit': debit,
          'total_credit': credit,
          'balance': debit - credit,
        });

    test('an untouched account has no activity', () {
      // A freshly provisioned branch has forty of these; showing them all
      // buries the handful that matter.
      expect(row().hasActivity, isFalse);
      expect(row(debit: 150000).hasActivity, isTrue);
    });
  });

  group('JournalEntryModel', () {
    JournalEntryModel entry({
      required List<Map<String, Object?>> lines,
      String? reversesId,
    }) => JournalEntryModel.fromJson(<String, Object?>{
      'id': 't1',
      'showroom_id': 'sr1',
      'transaction_date': '2026-09-16',
      'reference_type': 'PURCHASE',
      'description': 'Purchase SMI/PUR/2627/00001',
      'reverses_transaction_id': reversesId,
      'users': <String, Object?>{'name': 'Asha'},
      'accounting_entries': lines,
    });

    Map<String, Object?> line(String code, double debit, double credit) =>
        <String, Object?>{
          'id': '$code-$debit-$credit',
          'transaction_id': 't1',
          'account_id': 'acc-$code',
          'debit': debit,
          'credit': credit,
          'accounts': <String, Object?>{
            'account_code': code,
            'account_name': 'Account $code',
          },
        };

    test('sums both sides and reports a balanced entry', () {
      // The receipt posting as migration 017 leaves it: inventory, input tax
      // credit and inward freight against the supplier payable.
      final JournalEntryModel posting = entry(
        lines: <Map<String, Object?>>[
          line('1004', 150000, 0),
          line('1005', 42000, 0),
          line('5104', 2000, 0),
          line('2001', 0, 194000),
        ],
      );
      expect(posting.totalDebit, 194000);
      expect(posting.totalCredit, 194000);
      expect(posting.isBalanced, isTrue);
      expect(posting.lines, hasLength(4));
      expect(posting.lines.first.accountLabel, '1004 - Account 1004');
    });

    test('reports the imbalance the freight bug produced', () {
      // Regression marker: before migration 017 the receipt omitted the
      // freight debit, so the credit exceeded the debits by exactly
      // `other_charges` and `assert_ledger_balanced` refused the whole
      // transaction.
      final JournalEntryModel broken = entry(
        lines: <Map<String, Object?>>[
          line('1004', 150000, 0),
          line('1005', 42000, 0),
          line('2001', 0, 194000),
        ],
      );
      expect(broken.totalDebit, 192000);
      expect(broken.totalCredit, 194000);
      expect(broken.isBalanced, isFalse);
    });

    test('identifies a contra entry', () {
      expect(
        entry(lines: <Map<String, Object?>>[], reversesId: 't0').isReversal,
        isTrue,
      );
      expect(entry(lines: <Map<String, Object?>>[]).isReversal, isFalse);
    });

    test('splits debit and credit lines', () {
      final JournalEntryModel posting = entry(
        lines: <Map<String, Object?>>[
          line('1004', 150000, 0),
          line('2001', 0, 150000),
        ],
      );
      expect(posting.lines.first.isDebit, isTrue);
      expect(posting.lines.last.isDebit, isFalse);
    });
  });
}
