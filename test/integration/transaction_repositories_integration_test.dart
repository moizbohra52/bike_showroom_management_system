// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/billing/repositories/invoice_repository.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';
import 'package:bike_showroom_management_system/features/emi/repositories/emi_repository.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/finance_company_repository.dart';
import 'package:bike_showroom_management_system/features/finance/repositories/loan_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/payments/models/payment_model.dart';
import 'package:bike_showroom_management_system/features/payments/repositories/payment_repository.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:bike_showroom_management_system/features/sales/repositories/sale_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' as supabase;

/// Exercises the Phase 5 transaction repositories against a **real** PostgREST
/// instance.
///
/// Everything here is an RPC whose contract is a `jsonb` payload — a shape the
/// Dart compiler cannot check at all. A misspelled key does not fail to
/// compile, does not fail a unit test with a hand-written fixture, and does
/// not even fail loudly at runtime: the function simply reads null and carries
/// on with a default. The only way to know a sale really allocates the stock,
/// balances the ledger and builds the EMI schedule is to run it.
///
/// ## Cleanup, deliberately absent
///
/// Sales, invoices and payments are **not** deleted afterwards. §42 forbids
/// physically deleting a financial record, and `guard_no_financial_delete`
/// enforces it — so a tear-down that tried would fail. Each run tags its own
/// rows instead, and the sale created here is cancelled through the proper
/// RPC, which is itself one of the assertions.
///
/// Skipped unless a live server is described in the environment; see
/// `tools/local_backend/README.md`.
void main() {
  final String? baseUrl = Platform.environment['SUPABASE_TEST_URL'];
  final String? jwtSecret = Platform.environment['SUPABASE_TEST_JWT_SECRET'];
  final String? sub = Platform.environment['SUPABASE_TEST_SUB'];
  final String? showroomId = Platform.environment['SUPABASE_TEST_SHOWROOM_ID'];

  final bool isConfigured =
      baseUrl != null && jwtSecret != null && sub != null && showroomId != null;

  group('Transaction repositories against a live PostgREST instance', () {
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
    late SaleRepository sales;
    late InvoiceRepository invoices;
    late PaymentRepository payments;
    late LoanRepository loans;
    late EmiRepository emis;
    late FinanceCompanyRepository financiers;
    late InventoryRepository inventory;

    // Chassis numbers must match `^[A-HJ-NPR-Z0-9]{11,25}$` - I, O and Q are
    // excluded, which is why the tag is digits only.
    final String tag = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(5);

    String? productId;
    String? customerId;

    late String cashSaleId;
    late String cashInvoiceId;

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

      sales = SaleRepository(client: client);
      invoices = InvoiceRepository(client: client);
      payments = PaymentRepository(client: client);
      loans = LoanRepository(client: client);
      emis = EmiRepository(client: client);
      financiers = FinanceCompanyRepository(client: client);
      inventory = InventoryRepository(client: client);

      // Reuse whatever catalogue and customer the database already has: this
      // suite is about the transactions, not about creating master data.
      final List<dynamic> productRows = await client
          .from('products')
          .select('id')
          .eq('status', 'ACTIVE')
          .inFilter('category', <String>['MOTORCYCLE', 'SCOOTER'])
          .limit(1);
      productId = productRows.isEmpty
          ? null
          : (productRows.first as Map<String, dynamic>)['id'] as String;

      final List<dynamic> customerRows = await client
          .from('customers')
          .select('id')
          .eq('showroom_id', showroomId)
          .eq('is_deleted', false)
          .limit(1);
      customerId = customerRows.isEmpty
          ? null
          : (customerRows.first as Map<String, dynamic>)['id'] as String;
    });

    /// Takes a fresh unit into stock for one of the sales below.
    Future<InventoryModel> freshUnit(String suffix) async {
      final String stockCode = await inventory.nextStockCode(showroomId);
      return inventory.create(<String, Object?>{
        'showroom_id': showroomId,
        'product_id': productId,
        'stock_code': stockCode,
        'chassis_number': 'ZZ$suffix$tag',
        'engine_number': 'ZZE$suffix$tag',
        'purchase_price': 78000,
        'status': 'AVAILABLE',
      });
    }

    test('fixtures exist', () {
      expect(
        productId,
        isNotNull,
        reason: 'Seed a vehicle product before running this suite',
      );
      expect(
        customerId,
        isNotNull,
        reason: 'Seed a customer at the test showroom',
      );
    });

    test(
      'a cash sale allocates stock, invoices and balances the ledger',
      () async {
        final InventoryModel unit = await freshUnit('A');

        final SaleTransactionResult result = await sales.createSale(
          <String, Object?>{
            'showroom_id': showroomId,
            'customer_id': customerId,
            'sale_type': 'CASH',
            'items': <Map<String, Object?>>[
              <String, Object?>{
                'inventory_id': unit.id,
                'quantity': 1,
                'unit_price': 89500,
                'discount': 2000,
                'tax_rate': 28,
              },
            ],
            'other_charges': 1500,
            'paid_amount': 20000,
            'payment_method': 'CASH',
          },
        );
        cashSaleId = result.saleId;
        cashInvoiceId = result.invoiceId!;

        // (89500 - 2000) * 1.28 + 1500. The server recomputes this from the
        // catalogue, so agreement here means the client's preview arithmetic
        // matches the authority.
        expect(result.totalAmount, closeTo(113500, 0.01));
        expect(result.outstanding, closeTo(93500, 0.01));
        expect(result.invoiceNumber, isNotNull);
        // A serialised vehicle registers itself against the customer.
        expect(result.vehicleId, isNotNull);
        expect(result.loanId, isNull, reason: 'a cash sale raises no loan');

        // The unit left the floor.
        final InventoryModel sold = await inventory.getById(unit.id);
        expect(sold.status, InventoryStatus.sold);
      },
    );

    test('the sale reads back with every embed resolved', () async {
      // `sales` references `users` four times; a bare `users(...)` embed is
      // rejected with PGRST201, so the select must name the foreign key.
      final SaleModel sale = await sales.getDetail(cashSaleId);

      expect(sale.customerName, isNotNull);
      expect(sale.salespersonName, isNotNull);
      expect(sale.invoiceNumber, isNotNull);
      expect(sale.items, hasLength(1));
      expect(sale.items.single.stockCode, isNotNull);
      expect(sale.status, SaleStatus.confirmed);
    });

    test('the invoice carries the down payment already applied', () async {
      final InvoiceModel invoice = await invoices.getDetail(cashInvoiceId);

      expect(invoice.paidAmount, closeTo(20000, 0.01));
      expect(invoice.outstandingAmount, closeTo(93500, 0.01));
      expect(invoice.items, isNotEmpty);
      expect(invoice.customerName, isNotNull);
      expect(invoice.acceptsPayment, isTrue);
      // Raised by the sale, then issued - never left in DRAFT.
      expect(invoice.status, isNot(InvoiceStatus.draft));
    });

    test('a payment moves the invoice balance', () async {
      final String paymentId = await payments.recordPayment(<String, Object?>{
        'showroom_id': showroomId,
        'invoice_id': cashInvoiceId,
        'customer_id': customerId,
        'amount': 500,
        'payment_method': 'UPI',
        'allocation': 'INVOICE',
        'reference_number': 'UPI$tag',
      });

      final PaymentModel payment = await payments.getById(paymentId);
      expect(payment.amount, closeTo(500, 0.01));
      expect(payment.requiresReference, isTrue);
      expect(payment.referenceNumber, 'UPI$tag');
      expect(payment.canReverse, isTrue);

      final InvoiceModel invoice = await invoices.getById(cashInvoiceId);
      expect(invoice.paidAmount, closeTo(20500, 0.01));
      expect(invoice.outstandingAmount, closeTo(93000, 0.01));
    });

    test('a non-cash payment without a reference is refused', () async {
      // Unreconcilable against a bank statement, so the server rejects it.
      // The client blocks this too; this proves the server does as well.
      await expectLater(
        payments.recordPayment(<String, Object?>{
          'showroom_id': showroomId,
          'invoice_id': cashInvoiceId,
          'amount': 100,
          'payment_method': 'CHEQUE',
          'allocation': 'INVOICE',
        }),
        throwsA(anything),
      );
    });

    test('an overpayment is refused rather than going negative', () async {
      await expectLater(
        payments.recordPayment(<String, Object?>{
          'showroom_id': showroomId,
          'invoice_id': cashInvoiceId,
          'amount': 999999,
          'payment_method': 'CASH',
          'allocation': 'INVOICE',
        }),
        throwsA(anything),
      );
    });

    test(
      'reversing a payment restores the balance and keeps the receipt',
      () async {
        final String paymentId = await payments.recordPayment(<String, Object?>{
          'showroom_id': showroomId,
          'invoice_id': cashInvoiceId,
          'customer_id': customerId,
          'amount': 1000,
          'payment_method': 'CASH',
          'allocation': 'INVOICE',
        });

        final InvoiceModel afterPayment = await invoices.getById(cashInvoiceId);
        expect(afterPayment.paidAmount, closeTo(21500, 0.01));

        await payments.reversePayment(
          paymentId: paymentId,
          reason: 'Integration test reversal',
        );

        final InvoiceModel afterReversal = await invoices.getById(
          cashInvoiceId,
        );
        expect(afterReversal.paidAmount, closeTo(20500, 0.01));

        // The original receipt survives - the customer holds a copy of it, so
        // the ledger shows both the receipt and its contra.
        final PaymentModel original = await payments.getById(paymentId);
        expect(original.isReversed, isTrue);
        expect(original.canReverse, isFalse);
      },
    );

    test('a financed sale builds the loan and its whole schedule', () async {
      final List<dynamic> financierRows = await financiers.listActive();
      expect(
        financierRows,
        isNotEmpty,
        reason: '014_seed_data.sql should have seeded financiers',
      );
      final String financierId = (financierRows.first as dynamic).id as String;

      final InventoryModel unit = await freshUnit('B');

      final SaleTransactionResult result = await sales.createSale(
        <String, Object?>{
          'showroom_id': showroomId,
          'customer_id': customerId,
          'sale_type': 'FINANCE',
          'items': <Map<String, Object?>>[
            <String, Object?>{
              'inventory_id': unit.id,
              'quantity': 1,
              'unit_price': 89500,
              'tax_rate': 28,
            },
          ],
          'paid_amount': 15000,
          'payment_method': 'CASH',
          'loan': <String, Object?>{
            'finance_company_id': financierId,
            'loan_amount': 114560,
            'down_payment': 15000,
            'interest_rate': 11.5,
            'interest_type': 'REDUCING',
            'tenure_months': 24,
            'processing_fee': 1500,
          },
        },
      );

      expect(result.loanId, isNotNull);

      final LoanModel loan = await loans.getById(result.loanId!);
      // Principal is the sale value less the down payment, computed server
      // side - the client sends the gross and does not get to decide it.
      expect(loan.loanAmount, closeTo(99560, 0.01));
      expect(loan.tenureMonths, 24);
      expect(loan.emiAmount, greaterThan(0));
      expect(loan.financeCompanyName, isNotNull);
      expect(loan.customerName, isNotNull);
      expect(loan.saleNumber, isNotNull);

      final List<EmiScheduleModel> schedule = await emis.listForLoan(loan.id);
      expect(schedule, hasLength(24));
      expect(schedule.first.emiNumber, 1);
      expect(schedule.last.emiNumber, 24);
      // The schedule must amortise to exactly the principal, or the customer
      // ends up owing a rounding remainder nobody can account for.
      final double principalSum = schedule.fold<double>(
        0,
        (double sum, EmiScheduleModel e) => sum + e.principalAmount,
      );
      expect(principalSum, closeTo(loan.loanAmount, 0.5));
      // Due dates step forward a month at a time.
      expect(schedule[1].dueDate.isAfter(schedule.first.dueDate), isTrue);
      expect(schedule.first.customerName, isNotNull);
    });

    test('instalments filter by branch through the embedded loan', () async {
      // `emi_schedules` has no showroom_id, so the scope goes through
      // `loans!inner(...)` and a `loans.showroom_id` filter. Getting this
      // wrong would either fail outright or silently return other branches.
      final PaginatedResponse<EmiScheduleModel> page = await emis
          .listOutstanding(showroomId: showroomId, pageSize: 5);
      expect(page.items, isNotEmpty);
      expect(page.items.every((EmiScheduleModel e) => !e.isPaid), isTrue);

      final PaginatedResponse<EmiScheduleModel> elsewhere = await emis.list(
        QueryParams(
          pageSize: 5,
          filters: <QueryFilter>[
            EmiRepository.showroomFilter(
              '00000000-0000-0000-0000-000000000000',
            ),
          ],
        ),
      );
      expect(elsewhere.items, isEmpty);
    });

    test('cancelling a sale returns the unit to stock', () async {
      final SaleModel before = await sales.getDetail(cashSaleId);
      final String unitId = before.items.single.inventoryId!;

      await sales.cancelSale(
        saleId: cashSaleId,
        reason: 'Integration test cancellation',
      );

      final SaleModel after = await sales.getById(cashSaleId);
      expect(after.status, SaleStatus.cancelled);
      expect(after.canCancel, isFalse);

      // The vehicle is back on the floor rather than stranded as SOLD.
      final InventoryModel unit = await inventory.getById(unitId);
      expect(unit.status, isNot(InventoryStatus.sold));
      expect(unit.isAllocatable, isTrue);
    });

    test('the ledger is still balanced after all of it', () async {
      // The one assertion that catches a transaction posting only half its
      // entries: across every account, total debits must equal total credits.
      //
      // Read from the `trial_balance` view rather than by calling
      // `assert_ledger_balanced()` — that is a *trigger* function, so it takes
      // a trigger context and cannot be invoked as an RPC at all. It guards
      // each posting as it happens; this checks the result of all of them.
      final List<dynamic> rows = await client
          .from('trial_balance')
          .select('total_debit, total_credit')
          .eq('showroom_id', showroomId);

      double debits = 0;
      double credits = 0;
      for (final dynamic row in rows) {
        final Map<String, dynamic> account = row as Map<String, dynamic>;
        debits += (account['total_debit'] as num?)?.toDouble() ?? 0;
        credits += (account['total_credit'] as num?)?.toDouble() ?? 0;
      }

      expect(rows, isNotEmpty, reason: 'the chart of accounts should exist');
      expect(debits, greaterThan(0), reason: 'these tests posted entries');
      // A paisa of tolerance, matching the trigger's own.
      expect(debits, closeTo(credits, 0.01));
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
    // Null-aware element: an anon token carries no subject at all,
    // rather than a null one.
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
