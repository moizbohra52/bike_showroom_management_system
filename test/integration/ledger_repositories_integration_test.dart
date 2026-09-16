// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/accounting/models/account_model.dart';
import 'package:bike_showroom_management_system/features/accounting/models/journal_entry_model.dart';
import 'package:bike_showroom_management_system/features/accounting/repositories/account_repository.dart';
import 'package:bike_showroom_management_system/features/accounting/repositories/journal_repository.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_category_model.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_model.dart';
import 'package:bike_showroom_management_system/features/expenses/repositories/expense_category_repository.dart';
import 'package:bike_showroom_management_system/features/expenses/repositories/expense_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';
import 'package:bike_showroom_management_system/features/purchases/models/supplier_model.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/purchase_repository.dart';
import 'package:bike_showroom_management_system/features/purchases/repositories/supplier_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' as supabase;

/// Exercises the Phase 6 repositories — purchases, expenses and the ledger —
/// against a **real** PostgREST instance.
///
/// This suite found a genuine defect in the migrations that no amount of unit
/// testing could have: `receive_purchase` credited the supplier with the
/// purchase's full total while debiting only the goods and the tax, so
/// `other_charges` appeared on one side of the posting and not the other. Any
/// consignment with freight was impossible to receive —
/// `assert_ledger_balanced` refused the transaction outright. Migration 017
/// adds the missing debit; the test below is what keeps it fixed.
///
/// Sales, purchases, invoices, payments and expenses are never deleted
/// afterwards — §42 forbids it and `guard_no_financial_delete` enforces it.
/// Each run tags its own rows.
///
/// Skipped unless a live server is described in the environment.
void main() {
  final String? baseUrl = Platform.environment['SUPABASE_TEST_URL'];
  final String? jwtSecret = Platform.environment['SUPABASE_TEST_JWT_SECRET'];
  final String? sub = Platform.environment['SUPABASE_TEST_SUB'];
  final String? showroomId = Platform.environment['SUPABASE_TEST_SHOWROOM_ID'];

  final bool isConfigured =
      baseUrl != null && jwtSecret != null && sub != null && showroomId != null;

  group('Ledger repositories against a live PostgREST instance', () {
    if (!isConfigured) {
      test(
        'SKIPPED - set SUPABASE_TEST_URL / _JWT_SECRET / _SUB / _SHOWROOM_ID '
        'to run this against a live server',
        () {},
        skip: 'No live server configured; see the file header.',
      );
      return;
    }

    late supabase.SupabaseClient client;
    late SupplierRepository suppliers;
    late PurchaseRepository purchases;
    late ExpenseRepository expenses;
    late ExpenseCategoryRepository categories;
    late AccountRepository accounts;
    late JournalRepository journal;
    late InventoryRepository inventory;

    // Chassis numbers exclude I, O and Q, so the tag is digits only.
    final String tag = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(5);

    String? productId;
    String? supplierId;
    late String purchaseId;

    setUpAll(() async {
      final String anonJwt = _mintJwt(jwtSecret, sub: null, role: 'anon');
      final String userJwt = _mintJwt(
        jwtSecret,
        sub: sub,
        role: 'authenticated',
      );
      client = supabase.SupabaseClient(
        baseUrl,
        anonJwt,
        accessToken: () async => userJwt,
      );

      suppliers = SupplierRepository(client: client);
      purchases = PurchaseRepository(client: client);
      expenses = ExpenseRepository(client: client);
      categories = ExpenseCategoryRepository(client: client);
      accounts = AccountRepository(client: client);
      journal = JournalRepository(client: client);
      inventory = InventoryRepository(client: client);

      final List<dynamic> productRows = await client
          .from('products')
          .select('id')
          .eq('status', 'ACTIVE')
          .inFilter('category', <String>['MOTORCYCLE', 'SCOOTER'])
          .limit(1);
      productId = productRows.isEmpty
          ? null
          : (productRows.first as Map<String, dynamic>)['id'] as String;
    });

    test('a supplier can be created and listed', () async {
      final SupplierModel created = await suppliers.create(<String, Object?>{
        'name': 'Integration Supplier $tag',
        'code': 'SUP$tag',
        'gst_number': '23AAACH1234A1Z7',
        'city': 'Indore',
      });
      supplierId = created.id;

      expect(created.name, contains('Integration Supplier'));
      expect(created.isActive, isTrue);

      final List<SupplierModel> active = await suppliers.listActive();
      expect(
        active.any((SupplierModel s) => s.id == supplierId),
        isTrue,
        reason: 'a new supplier should appear in the picker',
      );
    });

    test('a purchase order totals correctly and creates no stock', () async {
      expect(productId, isNotNull, reason: 'seed a vehicle product first');

      purchaseId = await purchases.createPurchase(<String, Object?>{
        'showroom_id': showroomId,
        'supplier_id': supplierId,
        'supplier_invoice_no': 'SUPINV-$tag',
        'items': <Map<String, Object?>>[
          <String, Object?>{
            'product_id': productId,
            'description': 'Integration line',
            'quantity': 2,
            'unit_cost': 75000,
            'tax_rate': 28,
          },
        ],
        // The figure that used to make receiving impossible.
        'other_charges': 2000,
      });

      final PurchaseModel purchase = await purchases.getDetail(purchaseId);
      // 2 x 75000 = 150000, +28% = 192000, + 2000 freight.
      expect(purchase.totalAmount, closeTo(194000, 0.01));
      expect(purchase.outstandingAmount, closeTo(194000, 0.01));
      expect(purchase.status, PurchaseStatus.ordered);
      expect(purchase.supplierName, contains('Integration Supplier'));
      expect(purchase.expectedUnitCount, 2);
      expect(purchase.canReceive, isTrue);

      // Ordering creates no machines: they do not exist until they arrive.
      expect(purchase.items.single.isReceived, isFalse);
    });

    test('receiving a consignment WITH freight balances the ledger', () async {
      // The regression. Before migration 017 this call failed with
      // "Accounting entry is not balanced: debits 192000.00, credits
      // 194000.00" and rolled back, leaving the order permanently
      // unreceivable.
      final int created = await purchases.receivePurchase(<String, Object?>{
        'purchase_id': purchaseId,
        'units': <Map<String, Object?>>[
          <String, Object?>{
            'product_id': productId,
            'chassis_number': 'ZZPA$tag',
            'engine_number': 'ZZEPA$tag',
            'purchase_price': 75000,
          },
          <String, Object?>{
            'product_id': productId,
            'chassis_number': 'ZZPB$tag',
            'engine_number': 'ZZEPB$tag',
            'purchase_price': 75000,
          },
        ],
      });

      expect(created, 2);

      final PurchaseModel received = await purchases.getDetail(purchaseId);
      expect(received.status, PurchaseStatus.received);
      expect(received.canReceive, isFalse);
      expect(received.receivedDate, isNotNull);
    });

    test('the received machines are on the floor', () async {
      final PaginatedResponse<InventoryModel> page = await inventory.list(
        QueryParams(
          pageSize: 10,
          showroomId: showroomId,
          filters: <QueryFilter>[QueryFilter.equals('purchase_id', purchaseId)],
        ),
      );
      expect(page.items, hasLength(2));
      expect(
        page.items.every((InventoryModel u) => u.isAllocatable),
        isTrue,
        reason: 'received stock should be sellable',
      );
      // Each machine carries its own cost, which is what COGS is derived from.
      expect(page.items.first.purchasePrice, closeTo(75000, 0.01));
    });

    test('the receipt posting carries the freight debit', () async {
      final PaginatedResponse<JournalEntryModel> page = await journal.list(
        QueryParams(
          pageSize: 20,
          showroomId: showroomId,
          filters: <QueryFilter>[
            QueryFilter.equals('reference_type', 'PURCHASE'),
            QueryFilter.equals('reference_id', purchaseId),
          ],
        ),
      );
      expect(page.items, hasLength(1));

      final JournalEntryModel posting = page.items.single;
      expect(posting.isBalanced, isTrue);
      expect(posting.totalDebit, closeTo(194000, 0.01));

      final Set<String?> codes = posting.lines
          .map((JournalLineModel l) => l.accountCode)
          .toSet();
      expect(codes, contains('1004')); // inventory
      expect(codes, contains('1005')); // input tax credit
      expect(codes, contains('2001')); // supplier payable
      // The line migration 017 added. Its absence was the whole defect.
      expect(
        codes,
        contains('5104'),
        reason: 'inward freight must be debited, not only credited',
      );
    });

    test('receiving twice is refused', () async {
      await expectLater(
        purchases.receivePurchase(<String, Object?>{
          'purchase_id': purchaseId,
          'units': <Map<String, Object?>>[
            <String, Object?>{
              'product_id': productId,
              'chassis_number': 'ZZPC$tag',
              'engine_number': 'ZZEPC$tag',
            },
          ],
        }),
        throwsA(anything),
      );
    });

    test('an expense records and lands awaiting approval', () async {
      final List<ExpenseCategoryModel> active = await categories.listActive();
      expect(
        active,
        isNotEmpty,
        reason: '014_seed_data.sql should have seeded expense categories',
      );
      final ExpenseCategoryModel category = active.firstWhere(
        (ExpenseCategoryModel c) => c.isPostable,
        orElse: () => active.first,
      );

      final String expenseId = await expenses.createExpense(<String, Object?>{
        'showroom_id': showroomId,
        'category_id': category.id,
        'amount': 45000,
        'tax_amount': 8100,
        'payment_method': 'BANK_TRANSFER',
        'vendor_name': 'Integration Landlord',
        'reference_number': 'NEFT$tag',
        'description': 'Integration rent',
      });

      final ExpenseModel expense = await expenses.getById(expenseId);
      expect(expense.totalAmount, closeTo(53100, 0.01));
      // Recorded, not yet posted — approval is a separate act.
      expect(expense.status, ExpenseStatus.pending);
      expect(expense.categoryName, isNotNull);
      expect(expense.requiresReference, isTrue);
      expect(expense.createdBy, isNotNull);

      // The caller here is a super admin, whom `approve_expense` exempts from
      // the self-approval rule — so the client must agree that they may
      // decide it, or the button would be hidden from the only account that
      // can use it.
      expect(
        expense.canBeDecidedBy(expense.createdBy, isSuperAdmin: true),
        isTrue,
      );
      expect(expense.canBeDecidedBy(expense.createdBy), isFalse);

      await expenses.decide(expenseId: expenseId, approve: true);

      final ExpenseModel approved = await expenses.getById(expenseId);
      expect(approved.status, ExpenseStatus.approved);
      expect(approved.approvedByName, isNotNull);
      // A decided expense cannot be decided again.
      expect(
        approved.canBeDecidedBy('someone-else', isSuperAdmin: true),
        isFalse,
      );
    });

    test('deciding an already-decided expense is refused', () async {
      final PaginatedResponse<ExpenseModel> page = await expenses.list(
        QueryParams(
          pageSize: 1,
          showroomId: showroomId,
          filters: <QueryFilter>[
            QueryFilter.equals('status', ExpenseStatus.approved.value),
          ],
        ),
      );
      expect(page.items, isNotEmpty);

      await expectLater(
        expenses.decide(expenseId: page.items.single.id, approve: true),
        throwsA(anything),
      );
    });

    test('the chart of accounts is provisioned for the branch', () async {
      final List<AccountModel> chart = await accounts.listChart(showroomId);
      expect(chart, isNotEmpty);

      final Set<String> codes = chart
          .map((AccountModel a) => a.accountCode)
          .toSet();
      // The codes the transaction functions resolve by name.
      for (final String code in <String>[
        '1003',
        '1004',
        '1005',
        '2001',
        '2002',
        '4001',
        '5104',
      ]) {
        expect(codes, contains(code), reason: code);
      }
      expect(
        chart.any((AccountModel a) => a.isSystemAccount),
        isTrue,
        reason: 'seeded accounts should be marked as system accounts',
      );
    });

    test('the trial balance balances', () async {
      final List<TrialBalanceRow> rows = await accounts.trialBalance(
        showroomId,
      );
      expect(rows, isNotEmpty);

      double debits = 0;
      double credits = 0;
      for (final TrialBalanceRow row in rows) {
        debits += row.totalDebit;
        credits += row.totalCredit;
      }
      expect(debits, greaterThan(0));
      expect(debits, closeTo(credits, 0.01));

      // Something must have been posted to inventory by the receipt above.
      final TrialBalanceRow stock = rows.firstWhere(
        (TrialBalanceRow r) => r.accountCode == '1004',
      );
      expect(stock.totalDebit, greaterThan(0));
    });

    test('every journal entry posted is itself balanced', () async {
      final PaginatedResponse<JournalEntryModel> page = await journal.list(
        QueryParams(pageSize: 50, showroomId: showroomId),
      );
      expect(page.items, isNotEmpty);
      for (final JournalEntryModel entry in page.items) {
        expect(
          entry.isBalanced,
          isTrue,
          reason: '${entry.referenceType.value} ${entry.description}',
        );
        expect(entry.lines, isNotEmpty);
      }
    });
  });
}

/// HS256 JWT, standing in for GoTrue. See the sibling integration tests.
String _mintJwt(String secret, {required String? sub, required String role}) {
  final Map<String, Object?> header = <String, Object?>{
    'alg': 'HS256',
    'typ': 'JWT',
  };
  final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final Map<String, Object?> payload = <String, Object?>{
    // Null-aware element: an anon token carries no subject at all, rather
    // than a null one.
    'sub': ?sub,
    'role': role,
    'iat': now,
    'exp': now + 3600,
  };

  String b64(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final String signingInput = '${b64(header)}.${b64(payload)}';
  final Hmac hmac = Hmac(sha256, utf8.encode(secret));
  final String signature = base64Url
      .encode(hmac.convert(utf8.encode(signingInput)).bytes)
      .replaceAll('=', '');

  return '$signingInput.$signature';
}
