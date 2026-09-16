import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyUtil.toDecimal', () {
    test('parses numbers, strings and formatted currency', () {
      expect(MoneyUtil.toDecimal(5), Decimal.fromInt(5));
      expect(MoneyUtil.toDecimal(5.25), Decimal.parse('5.25'));
      expect(MoneyUtil.toDecimal('1,23,456.78'), Decimal.parse('123456.78'));
      expect(MoneyUtil.toDecimal('₹1,000.50'), Decimal.parse('1000.50'));
    });

    test('degrades to zero rather than throwing on junk input', () {
      // Runs on every keystroke in a money field, so it must never throw.
      expect(MoneyUtil.toDecimal(null), Decimal.zero);
      expect(MoneyUtil.toDecimal(''), Decimal.zero);
      expect(MoneyUtil.toDecimal('abc'), Decimal.zero);
      expect(MoneyUtil.toDecimal(double.nan), Decimal.zero);
      expect(MoneyUtil.toDecimal(double.infinity), Decimal.zero);
    });
  });

  group('MoneyUtil.computeLine', () {
    test('is exact where binary floating point would drift', () {
      // 0.1 * 3 in double is 0.30000000000000004.
      final LineAmounts line = MoneyUtil.computeLine(
        quantity: 3,
        unitPrice: 0.1,
      );
      expect(line.subtotal, Decimal.parse('0.30'));
      expect(line.total, Decimal.parse('0.30'));
    });

    test('applies discount before tax', () {
      // 100000 - 10% = 90000, GST 18% = 16200, total 106200.
      final LineAmounts line = MoneyUtil.computeLine(
        quantity: 1,
        unitPrice: 100000,
        discountPercent: 10,
        taxRate: 18,
      );
      expect(line.subtotal, Decimal.parse('100000.00'));
      expect(line.discount, Decimal.parse('10000.00'));
      expect(line.taxableValue, Decimal.parse('90000.00'));
      expect(line.taxAmount, Decimal.parse('16200.00'));
      expect(line.total, Decimal.parse('106200.00'));
    });

    test('absolute discount overrides percentage discount', () {
      final LineAmounts line = MoneyUtil.computeLine(
        quantity: 1,
        unitPrice: 50000,
        discountPercent: 10,
        discountAmount: 2500,
      );
      expect(line.discount, Decimal.parse('2500.00'));
    });

    test('clamps a discount that exceeds the line value', () {
      final LineAmounts line = MoneyUtil.computeLine(
        quantity: 1,
        unitPrice: 1000,
        discountAmount: 5000,
      );
      expect(line.discount, Decimal.parse('1000.00'));
      expect(line.total, Decimal.zero);
    });

    test('splits tax out of a tax-inclusive on-road price', () {
      // 118000 inclusive of 18% GST => tax 18000, total stays 118000.
      final LineAmounts line = MoneyUtil.computeLine(
        quantity: 1,
        unitPrice: 118000,
        taxRate: 18,
        priceIncludesTax: true,
      );
      expect(line.taxAmount, Decimal.parse('18000.00'));
      expect(line.total, Decimal.parse('118000.00'));
    });
  });

  group('MoneyUtil.computeDocument', () {
    test('sums lines and applies document-level discount and charges', () {
      final List<LineAmounts> lines = <LineAmounts>[
        MoneyUtil.computeLine(quantity: 1, unitPrice: 90000, taxRate: 18),
        MoneyUtil.computeLine(quantity: 2, unitPrice: 1500, taxRate: 18),
      ];
      final DocumentAmounts document = MoneyUtil.computeDocument(
        lines: lines,
        documentDiscountAmount: 1000,
        otherCharges: 12000,
      );

      expect(document.subtotal, Decimal.parse('93000.00'));
      // 90000*0.18 = 16200, 3000*0.18 = 540.
      expect(document.taxAmount, Decimal.parse('16740.00'));
      expect(document.discount, Decimal.parse('1000.00'));
      expect(document.otherCharges, Decimal.parse('12000.00'));
      // 93000 - 1000 + 16740 + 12000
      expect(document.total, Decimal.parse('120740.00'));
    });

    test('never produces a negative document total', () {
      final DocumentAmounts document = MoneyUtil.computeDocument(
        lines: <LineAmounts>[
          MoneyUtil.computeLine(quantity: 1, unitPrice: 100),
        ],
        documentDiscountAmount: 100,
      );
      expect(document.total, Decimal.zero);
    });
  });

  group('MoneyUtil.distribute', () {
    test('parts always sum back to the original amount', () {
      // The reason this helper exists: 100/3 loses a paisa if done naively.
      final List<Decimal> parts = MoneyUtil.distribute(
        Decimal.parse('100.00'),
        3,
      );
      expect(parts.length, 3);
      expect(
        parts.reduce((Decimal a, Decimal b) => a + b),
        Decimal.parse('100.00'),
      );
      expect(parts.first, Decimal.parse('33.34'));
      expect(parts[1], Decimal.parse('33.33'));
      expect(parts[2], Decimal.parse('33.33'));
    });

    test('handles an exactly divisible amount', () {
      final List<Decimal> parts = MoneyUtil.distribute(
        Decimal.parse('120.00'),
        4,
      );
      expect(parts.every((Decimal p) => p == Decimal.parse('30.00')), isTrue);
    });

    test('handles a realistic 36-month principal split', () {
      final List<Decimal> parts = MoneyUtil.distribute(
        Decimal.parse('85000.00'),
        36,
      );
      expect(parts.length, 36);
      expect(
        parts.reduce((Decimal a, Decimal b) => a + b),
        Decimal.parse('85000.00'),
      );
    });

    test('returns empty for a non-positive part count', () {
      expect(MoneyUtil.distribute(Decimal.parse('10.00'), 0), isEmpty);
    });
  });

  group('MoneyUtil.approximatelyEqual', () {
    test('absorbs sub-paisa rounding but flags real imbalance', () {
      expect(MoneyUtil.approximatelyEqual(1000.00, 1000.004), isTrue);
      expect(MoneyUtil.approximatelyEqual(1000.00, 1000.50), isFalse);
    });
  });

  group('MoneyUtil.percentageOf', () {
    test('computes a share and tolerates a zero denominator', () {
      expect(MoneyUtil.percentageOf(25, 200), closeTo(12.5, 0.0001));
      expect(MoneyUtil.percentageOf(25, 0), 0);
    });
  });

  group('MoneyUtil.toWords', () {
    test('uses Indian place values as required on a tax invoice', () {
      expect(MoneyUtil.toWords(0), 'Zero Rupees Only');
      expect(MoneyUtil.toWords(115), 'One Hundred Fifteen Rupees Only');
      expect(
        MoneyUtil.toWords(125000),
        'One Lakh Twenty Five Thousand Rupees Only',
      );
      expect(
        MoneyUtil.toWords(10250000),
        'One Crore Two Lakh Fifty Thousand Rupees Only',
      );
    });

    test('includes paise when present', () {
      expect(MoneyUtil.toWords(1.50), 'One Rupee and Fifty Paise Only');
    });

    test('uses singular nouns for exactly one unit', () {
      // These strings are printed on a tax invoice, so grammar matters.
      expect(MoneyUtil.toWords(1), 'One Rupee Only');
      expect(MoneyUtil.toWords(0.01), 'One Paisa Only');
    });
  });

  group('MoneyUtil formatting', () {
    test('formatRaw emits a fixed-scale string safe for a JSON payload', () {
      expect(MoneyUtil.formatRaw(1234.5), '1234.50');
      expect(MoneyUtil.formatRaw('1,234.567'), '1234.57');
    });

    test('normalise rounds half-up to the currency scale', () {
      expect(MoneyUtil.normalise('10.005'), 10.01);
      expect(MoneyUtil.normalise('10.004'), 10.00);
    });
  });
}
