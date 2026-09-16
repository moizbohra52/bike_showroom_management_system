import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';
import 'package:bike_showroom_management_system/features/payments/models/payment_model.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:flutter_test/flutter_test.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  group('SaleModel', () {
    Map<String, Object?> row({
      String status = 'CONFIRMED',
      double paid = 20000,
      double outstanding = 93500,
    }) => <String, Object?>{
      'id': 's1',
      'showroom_id': 'sr1',
      'customer_id': 'c1',
      'sale_number': 'SMI/SAL/2627/00001',
      'sale_date': '2026-09-15',
      'subtotal': 89500,
      'discount': 2000,
      'tax_amount': 24500,
      'other_charges': 1500,
      'total_amount': 113500,
      'paid_amount': paid,
      'outstanding_amount': outstanding,
      'sale_type': 'CASH',
      'status': status,
      'customers': <String, Object?>{'name': 'Ramesh', 'phone': '9876543210'},
      'users': <String, Object?>{'name': 'Asha'},
      'invoices': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'i1',
          'invoice_number': 'SMI/INV/2627/00001',
          'status': 'PARTIALLY_PAID',
        },
      ],
    };

    test('unwraps the invoice PostgREST returns as an array', () {
      // A sale raises exactly one invoice, but the relation is to-many from
      // the sale's side, so the embed always arrives wrapped in a list.
      final SaleModel sale = SaleModel.fromJson(row());
      expect(sale.invoiceNumber, 'SMI/INV/2627/00001');
      expect(sale.invoiceId, 'i1');
    });

    test('reads the salesperson from the FK-hinted embed', () {
      expect(SaleModel.fromJson(row()).salespersonName, 'Asha');
    });

    test('a part-paid sale still accepts payment', () {
      final SaleModel sale = SaleModel.fromJson(row());
      expect(sale.isFullyPaid, isFalse);
      expect(sale.acceptsPayment, isTrue);
      expect(sale.canCancel, isTrue);
    });

    test('a settled sale accepts no further payment', () {
      final SaleModel sale = SaleModel.fromJson(
        row(paid: 113500, outstanding: 0),
      );
      expect(sale.isFullyPaid, isTrue);
      expect(sale.acceptsPayment, isFalse);
    });

    test('a cancelled sale can be neither paid nor cancelled again', () {
      final SaleModel sale = SaleModel.fromJson(row(status: 'CANCELLED'));
      expect(sale.isCancelled, isTrue);
      expect(sale.acceptsPayment, isFalse);
      expect(sale.canCancel, isFalse);
    });

    test('discount percentage is measured against the pre-discount value', () {
      // This is the figure `create_sale_transaction` compares with the
      // showroom's approval threshold.
      final SaleModel sale = SaleModel.fromJson(row());
      expect(sale.discountPercentage, closeTo(2000 / 89500 * 100, 0.001));
    });

    test('a zero-value sale does not divide by zero', () {
      final SaleModel sale = SaleModel.fromJson(<String, Object?>{
        ...row(),
        'subtotal': 0,
        'discount': 0,
      });
      expect(sale.discountPercentage, 0);
    });

    test('the write payload carries nothing the server owns', () {
      // Amounts, status and the document number are all maintained
      // server-side; sending them back would let a stale form overwrite the
      // ledger's view of the sale.
      final Map<String, Object?> payload = SaleModel.fromJson(row()).toJson();
      for (final String key in <String>[
        'total_amount',
        'paid_amount',
        'outstanding_amount',
        'status',
        'sale_number',
      ]) {
        expect(payload.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('SaleTransactionResult', () {
    test('reads every identifier the RPC reports', () {
      final SaleTransactionResult result =
          SaleTransactionResult.fromJson(<String, Object?>{
            'sale_id': 's1',
            'sale_number': 'SMI/SAL/2627/00002',
            'invoice_id': 'i1',
            'invoice_number': 'SMI/INV/2627/00002',
            'vehicle_id': 'v1',
            'loan_id': 'l1',
            'payment_id': 'p1',
            'total_amount': 114560,
            'paid_amount': 15000,
            'outstanding': 99560,
          });
      expect(result.saleNumber, 'SMI/SAL/2627/00002');
      expect(result.loanId, 'l1');
      expect(result.outstanding, 99560);
    });

    test('a cash sale reports no loan', () {
      final SaleTransactionResult result = SaleTransactionResult.fromJson(
        <String, Object?>{'sale_id': 's1', 'sale_number': 'X', 'loan_id': null},
      );
      expect(result.loanId, isNull);
    });
  });

  group('InvoiceModel', () {
    Map<String, Object?> row({
      double paid = 0,
      double outstanding = 113500,
      String status = 'ISSUED',
      String? dueDate,
    }) => <String, Object?>{
      'id': 'i1',
      'showroom_id': 'sr1',
      'customer_id': 'c1',
      'invoice_number': 'SMI/INV/2627/00001',
      'invoice_date': '2026-09-15',
      'due_date': dueDate,
      'subtotal': 89500,
      'discount': 2000,
      'tax_amount': 24500,
      'other_charges': 1500,
      'total_amount': 113500,
      'paid_amount': paid,
      'outstanding_amount': outstanding,
      'status': status,
      'customers': <String, Object?>{
        'name': 'Ramesh',
        'gst_number': '23AAACS1234A1Z5',
      },
      'sales': <String, Object?>{'sale_number': 'SMI/SAL/2627/00001'},
    };

    test('taxable value is the subtotal net of discount', () {
      // The base a GST summary reports, and what each line's tax was charged
      // on.
      expect(InvoiceModel.fromJson(row()).taxableValue, 87500);
    });

    test('an unpaid invoice accepts payment', () {
      final InvoiceModel invoice = InvoiceModel.fromJson(row());
      expect(invoice.isPaid, isFalse);
      expect(invoice.acceptsPayment, isTrue);
    });

    test('a settled invoice is paid even if the status lags', () {
      // `record_payment` moves the balance; the status follows. Treating a
      // zero balance as paid stops the UI offering a payment that would then
      // be refused.
      final InvoiceModel invoice = InvoiceModel.fromJson(
        row(paid: 113500, outstanding: 0),
      );
      expect(invoice.isPaid, isTrue);
      expect(invoice.acceptsPayment, isFalse);
    });

    test('overdue needs a due date in the past and money owing', () {
      final String past = _iso(
        DateTime.now().subtract(const Duration(days: 10)),
      );
      final String future = _iso(DateTime.now().add(const Duration(days: 10)));

      expect(InvoiceModel.fromJson(row(dueDate: past)).isOverdue, isTrue);
      expect(InvoiceModel.fromJson(row(dueDate: future)).isOverdue, isFalse);
      // No due date means no overdue, not "overdue since the epoch".
      expect(InvoiceModel.fromJson(row()).isOverdue, isFalse);
      expect(
        InvoiceModel.fromJson(
          row(dueDate: past, paid: 113500, outstanding: 0),
        ).isOverdue,
        isFalse,
      );
    });

    test('prints the total in words, as an Indian tax invoice must', () {
      final String words = InvoiceModel.fromJson(row()).totalInWords;
      expect(words.toLowerCase(), contains('lakh'));
    });

    test('the write payload keeps out the immutable columns', () {
      final Map<String, Object?> payload = InvoiceModel.fromJson(
        row(),
      ).toJson();
      for (final String key in <String>[
        'total_amount',
        'paid_amount',
        'outstanding_amount',
        'status',
        'invoice_number',
      ]) {
        expect(payload.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('PaymentModel', () {
    Map<String, Object?> row({
      String method = 'CASH',
      String status = 'COMPLETED',
      String? reversesId,
      String? reversedAt,
    }) => <String, Object?>{
      'id': 'p1',
      'showroom_id': 'sr1',
      'payment_number': 'SMI/PAY/2627/00001',
      'payment_date': '2026-09-15',
      'amount': 20000,
      'payment_method': method,
      'direction': 'INBOUND',
      'allocation': 'INVOICE',
      'status': status,
      'reverses_payment_id': reversesId,
      'reversed_at': reversedAt,
      'customers': <String, Object?>{'name': 'Ramesh'},
      'invoices': <String, Object?>{'invoice_number': 'SMI/INV/2627/00001'},
      'users': <String, Object?>{'name': 'Asha'},
    };

    test('reads the receiver from the FK-hinted embed', () {
      // `payments` references `users` three times, so the embed has to name
      // payments_received_by_fkey or PostgREST refuses the request.
      expect(PaymentModel.fromJson(row()).receivedByName, 'Asha');
    });

    test('only cash and mixed tenders skip the reference requirement', () {
      expect(PaymentModel.fromJson(row()).requiresReference, isFalse);
      expect(
        PaymentModel.fromJson(row(method: 'MIXED')).requiresReference,
        isFalse,
      );
      for (final String method in <String>[
        'UPI',
        'CARD',
        'BANK_TRANSFER',
        'CHEQUE',
      ]) {
        expect(
          PaymentModel.fromJson(row(method: method)).requiresReference,
          isTrue,
          reason: method,
        );
      }
    });

    test('a completed inbound payment can be reversed', () {
      expect(PaymentModel.fromJson(row()).canReverse, isTrue);
    });

    test('an already-reversed payment cannot be reversed again', () {
      expect(
        PaymentModel.fromJson(
          row(status: 'REVERSED', reversedAt: '2026-09-16T10:00:00Z'),
        ).canReverse,
        isFalse,
      );
    });

    test('a contra row is not itself reversible', () {
      // Reversing a reversal would be a reinstatement, which is a new
      // payment, not an undo.
      final PaymentModel contra = PaymentModel.fromJson(row(reversesId: 'p0'));
      expect(contra.isReversal, isTrue);
      expect(contra.canReverse, isFalse);
    });
  });

  group('LoanModel', () {
    LoanModel loan({
      double amount = 99560,
      double emi = 4663.42,
      int tenure = 24,
    }) => LoanModel.fromJson(<String, Object?>{
      'id': 'l1',
      'showroom_id': 'sr1',
      'customer_id': 'c1',
      'finance_company_id': 'f1',
      'loan_number': 'SMI/LON/2627/00001',
      'start_date': '2026-09-16',
      'loan_amount': amount,
      'down_payment': 15000,
      'interest_rate': 11.5,
      'interest_type': 'REDUCING',
      'tenure_months': tenure,
      'emi_amount': emi,
      'customers': <String, Object?>{'name': 'Ramesh'},
      'finance_companies': <String, Object?>{'name': 'Bajaj Finance'},
      'sales': <String, Object?>{'sale_number': 'SMI/SAL/2627/00002'},
    });

    test('total repayable is the instalment across the tenure', () {
      expect(loan().totalRepayable, closeTo(4663.42 * 24, 0.001));
    });

    test('cost of credit is everything repaid beyond the principal', () {
      // Worth surfacing: on a FLAT agreement this is markedly more than the
      // nominal rate suggests.
      expect(loan().totalInterest, closeTo(4663.42 * 24 - 99560, 0.01));
    });

    test('never reports a negative cost of credit', () {
      // A fully prepaid or mis-keyed agreement should read zero rather than a
      // negative figure the UI would print with a minus sign.
      expect(loan(emi: 100, tenure: 1).totalInterest, 0);
    });

    test('reads all three embedded relations', () {
      final LoanModel l = loan();
      expect(l.customerName, 'Ramesh');
      expect(l.financeCompanyName, 'Bajaj Finance');
      expect(l.saleNumber, 'SMI/SAL/2627/00002');
    });
  });

  group('EmiScheduleModel', () {
    EmiScheduleModel emi({
      required String dueDate,
      String status = 'UPCOMING',
      double remaining = 4663.42,
      double penalty = 0,
    }) => EmiScheduleModel.fromJson(<String, Object?>{
      'id': 'e1',
      'loan_id': 'l1',
      'emi_number': 3,
      'due_date': dueDate,
      'principal_amount': 3709.30,
      'interest_amount': 954.12,
      'emi_amount': 4663.42,
      'paid_amount': 4663.42 - remaining,
      'remaining_amount': remaining,
      'penalty_amount': penalty,
      'status': status,
      'loans': <String, Object?>{
        'loan_number': 'SMI/LON/2627/00001',
        'customers': <String, Object?>{'name': 'Ramesh', 'phone': '98765'},
      },
    });

    test('reads the customer through two levels of embed', () {
      final EmiScheduleModel e = emi(dueDate: '2026-12-16');
      expect(e.loanNumber, 'SMI/LON/2627/00001');
      expect(e.customerName, 'Ramesh');
    });

    test('amount due includes the penalty', () {
      // This is the figure quoted on a collections call, not the bare
      // instalment.
      expect(
        emi(dueDate: '2026-12-16', penalty: 250).amountDue,
        closeTo(4663.42 + 250, 0.001),
      );
    });

    test('a past due date with money owing is overdue', () {
      final String past = _iso(
        DateTime.now().subtract(const Duration(days: 5)),
      );
      final EmiScheduleModel late = emi(dueDate: past, status: 'OVERDUE');
      expect(late.isOverdue, isTrue);
      expect(late.daysOverdue, greaterThanOrEqualTo(4));
    });

    test('a settled instalment is never overdue, whatever the date', () {
      final String past = _iso(
        DateTime.now().subtract(const Duration(days: 30)),
      );
      final EmiScheduleModel paid = emi(
        dueDate: past,
        status: 'PAID',
        remaining: 0,
      );
      expect(paid.isPaid, isTrue);
      expect(paid.isOverdue, isFalse);
      expect(paid.daysOverdue, 0);
    });

    test('due soon covers the next fortnight but not beyond', () {
      final String soon = _iso(DateTime.now().add(const Duration(days: 7)));
      final String later = _iso(DateTime.now().add(const Duration(days: 45)));
      expect(emi(dueDate: soon).isDueSoon, isTrue);
      expect(emi(dueDate: later).isDueSoon, isFalse);
    });
  });
}
