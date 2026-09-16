import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Money arithmetic and formatting.
///
/// ## Why `Decimal` and not `double`
///
/// Binary floating point cannot represent 0.1, so accumulating line totals in
/// `double` drifts: `0.1 * 3` is `0.30000000000000004`. On an invoice with tax
/// and a percentage discount that drift becomes a visible one-paisa mismatch
/// between the line items and the total, and an unbalanced journal entry.
///
/// All computation here therefore runs through [Decimal] and is rounded to two
/// places only at the boundary.
///
/// ## Where authority lives
///
/// These helpers exist so the *form* can show a correct running total while the
/// user types. They are not the system of record. `create_sale_transaction()`
/// and `complete_service()` recompute every figure server-side in `numeric`
/// before anything is written, because a client can always be tampered with.
/// A mismatch between the two is a bug in one of them, and the server wins.
class MoneyUtil {
  const MoneyUtil._();

  static final Decimal _hundred = Decimal.fromInt(100);

  /// Smallest representable currency unit (one paisa).
  static final Decimal _unit = Decimal.parse('0.01');

  /// Division in `package:decimal` yields a [Rational], because the exact
  /// result of dividing two decimals may be non-terminating (1/3). Collapsing
  /// it back to a [Decimal] therefore requires an explicit precision, and that
  /// precision must be wider than the currency scale so the subsequent
  /// half-up [round] sees the correct trailing digits.
  static Decimal _divide(Decimal dividend, Decimal divisor) {
    if (divisor == Decimal.zero) {
      return Decimal.zero;
    }
    return (dividend / divisor).toDecimal(scaleOnInfinitePrecision: 10);
  }

  /// Rounds to the currency's precision using half-up, which is what Indian
  /// invoicing convention and PostgreSQL's `numeric` rounding both do.
  static Decimal round(Decimal value) =>
      value.round(scale: AppConstants.currencyDecimalPlaces);

  /// Parses an arbitrary numeric input into an exact decimal.
  ///
  /// Accepts `num`, `String` (with grouping separators and a currency symbol),
  /// and null. Unparseable input yields zero rather than throwing, because
  /// this runs on every keystroke in a form field.
  static Decimal toDecimal(Object? value) {
    if (value == null) {
      return Decimal.zero;
    }
    if (value is Decimal) {
      return value;
    }
    if (value is int) {
      return Decimal.fromInt(value);
    }
    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        return Decimal.zero;
      }
      return Decimal.parse(value.toString());
    }
    if (value is num) {
      return Decimal.parse(value.toString());
    }
    final String cleaned = value
        .toString()
        .replaceAll(AppConstants.defaultCurrencySymbol, '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
    if (cleaned.isEmpty) {
      return Decimal.zero;
    }
    return Decimal.tryParse(cleaned) ?? Decimal.zero;
  }

  /// Converts to the `double` used by models and JSON payloads.
  static double toDouble(Decimal value) => value.toDouble();

  /// Convenience: parse, round, and hand back a double for storage.
  static double normalise(Object? value) => toDouble(round(toDecimal(value)));

  // ------------------------------------------------------------ line maths

  /// Gross value of a line before discount and tax.
  static Decimal lineSubtotal({
    required Object? quantity,
    required Object? unitPrice,
  }) => round(toDecimal(quantity) * toDecimal(unitPrice));

  /// Resolves a discount that may be expressed as an absolute amount or as a
  /// percentage of [base].
  ///
  /// A discount can never exceed the base, and never be negative — both are
  /// also enforced by CHECK constraints on the tables.
  static Decimal resolveDiscount({
    required Decimal base,
    Object? discountAmount,
    Object? discountPercent,
  }) {
    Decimal discount = Decimal.zero;

    final Decimal percent = toDecimal(discountPercent);
    if (percent > Decimal.zero) {
      discount = round(_divide(base * percent, _hundred));
    }

    final Decimal absolute = toDecimal(discountAmount);
    if (absolute > Decimal.zero) {
      discount = absolute;
    }

    if (discount < Decimal.zero) {
      return Decimal.zero;
    }
    if (discount > base) {
      return base;
    }
    return round(discount);
  }

  /// Tax on a taxable amount at [taxRate] percent.
  ///
  /// Tax is always computed on the post-discount value. Charging tax on a
  /// discounted-away amount would overstate the liability to the tax authority.
  static Decimal taxOn({
    required Decimal taxableAmount,
    required Object? taxRate,
  }) {
    final Decimal rate = toDecimal(taxRate);
    if (rate <= Decimal.zero || taxableAmount <= Decimal.zero) {
      return Decimal.zero;
    }
    return round(_divide(taxableAmount * rate, _hundred));
  }

  /// Extracts the tax already contained in a tax-inclusive figure.
  ///
  /// `tax = inclusive * rate / (100 + rate)`. Used when a showroom quotes
  /// on-road prices that already include GST.
  static Decimal taxIncludedIn({
    required Decimal inclusiveAmount,
    required Object? taxRate,
  }) {
    final Decimal rate = toDecimal(taxRate);
    if (rate <= Decimal.zero || inclusiveAmount <= Decimal.zero) {
      return Decimal.zero;
    }
    return round(_divide(inclusiveAmount * rate, _hundred + rate));
  }

  /// Full computation for one document line.
  ///
  /// Returns the four figures a line needs, each independently rounded so that
  /// summing the column in the UI reproduces the document total exactly.
  static LineAmounts computeLine({
    required Object? quantity,
    required Object? unitPrice,
    Object? discountAmount,
    Object? discountPercent,
    Object? taxRate,
    bool priceIncludesTax = false,
  }) {
    final Decimal subtotal = lineSubtotal(
      quantity: quantity,
      unitPrice: unitPrice,
    );
    final Decimal discount = resolveDiscount(
      base: subtotal,
      discountAmount: discountAmount,
      discountPercent: discountPercent,
    );
    final Decimal taxable = subtotal - discount;

    final Decimal tax = priceIncludesTax
        ? taxIncludedIn(inclusiveAmount: taxable, taxRate: taxRate)
        : taxOn(taxableAmount: taxable, taxRate: taxRate);

    // When the quoted price already includes tax the total is the taxable
    // figure itself; the tax is a split of it, not an addition to it.
    final Decimal total = priceIncludesTax ? taxable : taxable + tax;

    return LineAmounts(
      subtotal: round(subtotal),
      discount: round(discount),
      taxAmount: round(tax),
      total: round(total),
    );
  }

  /// Sums a document from its already-computed lines, then applies a
  /// document-level discount and other charges.
  static DocumentAmounts computeDocument({
    required List<LineAmounts> lines,
    Object? documentDiscountAmount,
    Object? documentDiscountPercent,
    Object? otherCharges,
  }) {
    Decimal subtotal = Decimal.zero;
    Decimal lineDiscount = Decimal.zero;
    Decimal tax = Decimal.zero;

    for (final LineAmounts line in lines) {
      subtotal += line.subtotal;
      lineDiscount += line.discount;
      tax += line.taxAmount;
    }

    final Decimal netOfLineDiscount = subtotal - lineDiscount;
    final Decimal documentDiscount = resolveDiscount(
      base: netOfLineDiscount,
      discountAmount: documentDiscountAmount,
      discountPercent: documentDiscountPercent,
    );

    final Decimal charges = toDecimal(otherCharges);
    final Decimal total = netOfLineDiscount - documentDiscount + tax + charges;

    return DocumentAmounts(
      subtotal: round(subtotal),
      discount: round(lineDiscount + documentDiscount),
      taxAmount: round(tax),
      otherCharges: round(charges),
      total: round(total < Decimal.zero ? Decimal.zero : total),
    );
  }

  /// Percentage that [part] represents of [whole]; zero when [whole] is zero.
  static double percentageOf(Object? part, Object? whole) {
    final Decimal total = toDecimal(whole);
    if (total == Decimal.zero) {
      return 0;
    }
    return (_divide(toDecimal(part), total) * _hundred).toDouble();
  }

  /// Whether two amounts are equal within the ledger tolerance.
  ///
  /// Used when asserting that debits equal credits: a sub-paisa difference is
  /// a rounding artefact, anything larger is a real imbalance.
  static bool approximatelyEqual(Object? a, Object? b) =>
      (toDecimal(a) - toDecimal(b)).abs().toDouble() <=
      AppConstants.ledgerBalanceTolerance;

  /// Distributes [amount] across [parts] so the pieces sum back exactly.
  ///
  /// Naive division leaves a residue — splitting 100 three ways gives three
  /// 33.33s and loses a paisa. The remainder is pushed onto the first
  /// instalments, matching how EMI schedules are built server-side.
  static List<Decimal> distribute(Decimal amount, int parts) {
    if (parts <= 0) {
      return const <Decimal>[];
    }
    final Decimal each = round(_divide(amount, Decimal.fromInt(parts)));
    final List<Decimal> result = List<Decimal>.filled(
      parts,
      each,
      growable: true,
    );

    final Decimal allocated = each * Decimal.fromInt(parts);
    Decimal residue = round(amount - allocated);

    // Spread the residue one paisa at a time across the leading instalments.
    int index = 0;
    while (residue.abs() >= _unit && index < parts) {
      if (residue > Decimal.zero) {
        result[index] = round(result[index] + _unit);
        residue = round(residue - _unit);
      } else {
        result[index] = round(result[index] - _unit);
        residue = round(residue + _unit);
      }
      index++;
    }
    return result;
  }

  // ----------------------------------------------------------- formatting

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: AppConstants.defaultLocale,
    symbol: AppConstants.defaultCurrencySymbol,
    decimalDigits: AppConstants.currencyDecimalPlaces,
  );

  static final NumberFormat _currencyCompactFormat =
      NumberFormat.compactCurrency(
        locale: AppConstants.defaultLocale,
        symbol: AppConstants.defaultCurrencySymbol,
        decimalDigits: 1,
      );

  static final NumberFormat _plainFormat = NumberFormat.decimalPattern(
    AppConstants.defaultLocale,
  );

  /// `₹1,23,456.78` — full precision with Indian digit grouping.
  static String format(Object? value) =>
      _currencyFormat.format(toDecimal(value).toDouble());

  /// `₹1.2L` — for dashboard tiles where space is tight.
  static String formatCompact(Object? value) =>
      _currencyCompactFormat.format(toDecimal(value).toDouble());

  /// Amount without a currency symbol, for table cells and export columns.
  static String formatPlain(Object? value) {
    final double amount = toDecimal(value).toDouble();
    return _plainFormat.format(amount);
  }

  /// Fixed decimal string suitable for a JSON payload or a text field.
  static String formatRaw(Object? value) => round(
    toDecimal(value),
  ).toStringAsFixed(AppConstants.currencyDecimalPlaces);

  static String formatPercent(Object? value, {int decimals = 2}) {
    final double percent = toDecimal(value).toDouble();
    return '${percent.toStringAsFixed(decimals)}%';
  }

  /// Indian-numbering words for a printed invoice: statutory requirement on
  /// tax invoices in India, and expected on a delivery receipt.
  static String toWords(Object? value) {
    final Decimal amount = round(toDecimal(value)).abs();
    final BigInt rupees = amount.truncate().toBigInt();
    final int paise = ((amount - amount.truncate()) * _hundred)
        .round()
        .toBigInt()
        .toInt();

    final StringBuffer buffer = StringBuffer();
    if (rupees == BigInt.zero && paise == 0) {
      return 'Zero Rupees Only';
    }
    if (rupees > BigInt.zero) {
      final String noun = rupees == BigInt.one ? 'Rupee' : 'Rupees';
      buffer.write('${_indianWords(rupees)} $noun');
    }
    if (paise > 0) {
      if (buffer.isNotEmpty) {
        buffer.write(' and ');
      }
      final String noun = paise == 1 ? 'Paisa' : 'Paise';
      buffer.write('${_indianWords(BigInt.from(paise))} $noun');
    }
    buffer.write(' Only');
    return buffer.toString();
  }

  static const List<String> _units = <String>[
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = <String>[
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  /// Indian place values: thousand, lakh, crore, then crore-multiples.
  static String _indianWords(BigInt value) {
    if (value == BigInt.zero) {
      return 'Zero';
    }
    final List<String> parts = <String>[];
    BigInt remaining = value;

    final BigInt crore = BigInt.from(10000000);
    final BigInt lakh = BigInt.from(100000);
    final BigInt thousand = BigInt.from(1000);
    final BigInt hundred = BigInt.from(100);

    if (remaining >= crore) {
      final BigInt crores = remaining ~/ crore;
      parts.add('${_indianWords(crores)} Crore');
      remaining = remaining.remainder(crore);
    }
    if (remaining >= lakh) {
      final int lakhs = (remaining ~/ lakh).toInt();
      parts.add('${_twoDigitWords(lakhs)} Lakh');
      remaining = remaining.remainder(lakh);
    }
    if (remaining >= thousand) {
      final int thousands = (remaining ~/ thousand).toInt();
      parts.add('${_twoDigitWords(thousands)} Thousand');
      remaining = remaining.remainder(thousand);
    }
    if (remaining >= hundred) {
      final int hundreds = (remaining ~/ hundred).toInt();
      parts.add('${_units[hundreds]} Hundred');
      remaining = remaining.remainder(hundred);
    }
    if (remaining > BigInt.zero) {
      parts.add(_twoDigitWords(remaining.toInt()));
    }
    return parts.join(' ');
  }

  static String _twoDigitWords(int value) {
    if (value < 20) {
      return _units[value];
    }
    final int tens = value ~/ 10;
    final int unit = value % 10;
    return unit == 0 ? _tens[tens] : '${_tens[tens]} ${_units[unit]}';
  }
}

/// The four figures describing a single document line.
class LineAmounts {
  const LineAmounts({
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.total,
  });

  final Decimal subtotal;
  final Decimal discount;
  final Decimal taxAmount;
  final Decimal total;

  double get subtotalValue => subtotal.toDouble();
  double get discountValue => discount.toDouble();
  double get taxValue => taxAmount.toDouble();
  double get totalValue => total.toDouble();

  /// Taxable value after discount, shown as its own column on a GST invoice.
  Decimal get taxableValue => subtotal - discount;

  Map<String, double> toPayload() => <String, double>{
    'subtotal': subtotalValue,
    'discount': discountValue,
    'tax_amount': taxValue,
    'total_amount': totalValue,
  };
}

/// Aggregated figures for a whole document.
class DocumentAmounts {
  const DocumentAmounts({
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.otherCharges,
    required this.total,
  });

  final Decimal subtotal;
  final Decimal discount;
  final Decimal taxAmount;
  final Decimal otherCharges;
  final Decimal total;

  double get subtotalValue => subtotal.toDouble();
  double get discountValue => discount.toDouble();
  double get taxValue => taxAmount.toDouble();
  double get otherChargesValue => otherCharges.toDouble();
  double get totalValue => total.toDouble();

  Map<String, double> toPayload() => <String, double>{
    'subtotal': subtotalValue,
    'discount': discountValue,
    'tax_amount': taxValue,
    'other_charges': otherChargesValue,
    'total_amount': totalValue,
  };
}
