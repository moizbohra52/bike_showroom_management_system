import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:decimal/decimal.dart';

/// Form validators, returning `null` when valid and a message otherwise, which
/// is the signature Flutter's `FormFieldValidator` expects.
///
/// ## Defence in depth
///
/// Nothing here is a security control. Every rule enforced in this file is
/// *also* enforced by a CHECK constraint, a UNIQUE index or a `RAISE
/// EXCEPTION` inside the relevant database function, because a client-side
/// check is only a convenience for the person typing. The pairing is
/// documented per-validator so the two can be kept in step.
class AppValidators {
  const AppValidators._();

  // ------------------------------------------------------------------ core

  /// Mirrors a `NOT NULL` column.
  static String? required(Object? value, {String field = 'This field'}) {
    if (value == null) {
      return '$field is required';
    }
    if (value is String && value.trim().isEmpty) {
      return '$field is required';
    }
    if (value is Iterable && value.isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? minLength(
    String? value,
    int length, {
    String field = 'This field',
  }) {
    if (value == null || value.trim().length < length) {
      return '$field must be at least $length characters';
    }
    return null;
  }

  static String? maxLength(
    String? value,
    int length, {
    String field = 'This field',
  }) {
    if (value != null && value.trim().length > length) {
      return '$field must not exceed $length characters';
    }
    return null;
  }

  /// Runs validators in order and returns the first failure.
  ///
  /// Lets a field compose rules without nesting:
  /// `validator: (v) => AppValidators.compose(v, [AppValidators.requiredText, ...])`
  static String? compose(
    String? value,
    List<String? Function(String?)> validators,
  ) {
    for (final String? Function(String?) validator in validators) {
      final String? error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  /// Wraps a validator so it only applies when the value is non-empty,
  /// for genuinely optional fields.
  static String? Function(String?) optional(
    String? Function(String?) validator,
  ) => (String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return validator(value);
  };

  static String? requiredText(String? value) =>
      required(value, field: 'This field');

  // ------------------------------------------------------------- identity

  static final RegExp _emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+"
    r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  static String? email(String? value, {bool isRequired = true}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'Email address is required' : null;
    }
    if (trimmed.length > 254) {
      return 'Email address is too long';
    }
    if (!_emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Indian mobile number: ten digits beginning 6-9.
  ///
  /// Accepts and ignores a `+91`/`91`/`0` prefix and internal spaces, hyphens
  /// or brackets, because that is how numbers are realistically pasted in.
  /// Paired with `customers_phone_check` on the database.
  static String? phone(String? value, {bool isRequired = true}) {
    final String digits = normalisePhone(value);
    if (digits.isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    if (digits.length != 10) {
      return 'Enter a 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]').hasMatch(digits)) {
      return 'Mobile numbers start with 6, 7, 8 or 9';
    }
    return null;
  }

  /// Reduces any accepted phone spelling to bare ten digits for storage, so
  /// the UNIQUE index on `(showroom_id, phone)` is not defeated by formatting.
  static String normalisePhone(String? value) {
    if (value == null) {
      return '';
    }
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(digits.length - 10);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    } else if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// A landline or alternate contact: 6-15 digits, less strict than [phone].
  static String? alternatePhone(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final String digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6 || digits.length > 15) {
      return 'Enter a valid contact number';
    }
    return null;
  }

  /// Indian PIN code: six digits, first digit 1-9.
  static String? pincode(String? value, {bool isRequired = false}) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? 'PIN code is required' : null;
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(trimmed)) {
      return 'Enter a valid 6-digit PIN code';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp('[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp('[a-z]').hasMatch(value)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp('[0-9]').hasMatch(value)) {
      return 'Include at least one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) {
      return 'Please re-enter the password';
    }
    if (value != original) {
      return 'Passwords do not match';
    }
    return null;
  }

  // ------------------------------------------------------------ tax numbers

  static const String _gstCharset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// GSTIN: 15 characters, structured as
  /// `<2-digit state><10-char PAN><1 entity><Z><1 checksum>`.
  ///
  /// The trailing character is a mod-36 checksum, so a single mistyped
  /// character is detectable. Validating it here saves a rejected invoice
  /// later, since a wrong GSTIN makes the buyer unable to claim input credit.
  static String? gstNumber(String? value, {bool isRequired = false}) {
    final String trimmed = (value ?? '').trim().toUpperCase();
    if (trimmed.isEmpty) {
      return isRequired ? 'GST number is required' : null;
    }
    if (trimmed.length != 15) {
      return 'GST number must be exactly 15 characters';
    }
    if (!RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
    ).hasMatch(trimmed)) {
      return 'Enter a valid GST number';
    }
    final int stateCode = int.parse(trimmed.substring(0, 2));
    if (stateCode < 1 || stateCode > 38) {
      return 'The GST state code is not valid';
    }
    if (!isValidGstChecksum(trimmed)) {
      return 'GST number failed its checksum - please re-check';
    }
    return null;
  }

  /// Mod-36 checksum over the first 14 characters, alternating weights 1 and 2.
  static bool isValidGstChecksum(String gstin) {
    if (gstin.length != 15) {
      return false;
    }
    int sum = 0;
    for (int index = 0; index < 14; index++) {
      final int charValue = _gstCharset.indexOf(gstin[index]);
      if (charValue < 0) {
        return false;
      }
      final int factor = index.isEven ? 1 : 2;
      final int product = charValue * factor;
      sum += (product ~/ 36) + (product % 36);
    }
    final int checksum = (36 - (sum % 36)) % 36;
    return _gstCharset[checksum] == gstin[14];
  }

  /// PAN: `AAAAA9999A`. The fourth character encodes the holder type, and a
  /// wrong one is the most common data-entry error.
  static String? panNumber(String? value, {bool isRequired = false}) {
    final String trimmed = (value ?? '').trim().toUpperCase();
    if (trimmed.isEmpty) {
      return isRequired ? 'PAN is required' : null;
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(trimmed)) {
      return 'Enter a valid PAN (e.g. ABCDE1234F)';
    }
    const String validHolderTypes = 'ABCFGHJLPTK';
    if (!validHolderTypes.contains(trimmed[3])) {
      return 'The 4th character of the PAN is not a valid holder type';
    }
    return null;
  }

  // --------------------------------------------------------------- vehicle

  /// Chassis / VIN. Manufacturers omit I, O and Q to avoid confusion with
  /// 1 and 0, so those characters indicate a transcription error.
  ///
  /// Paired with `inventory.chassis_number` UNIQUE and its CHECK constraint.
  static String? chassisNumber(String? value, {bool isRequired = true}) {
    final String trimmed = (value ?? '').trim().toUpperCase();
    if (trimmed.isEmpty) {
      return isRequired ? 'Chassis number is required' : null;
    }
    if (trimmed.length < 11 || trimmed.length > 25) {
      return 'Chassis number must be 11 to 25 characters';
    }
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]+$').hasMatch(trimmed)) {
      return 'Chassis numbers use A-Z and 0-9, excluding I, O and Q';
    }
    return null;
  }

  static String? engineNumber(String? value, {bool isRequired = true}) {
    final String trimmed = (value ?? '').trim().toUpperCase();
    if (trimmed.isEmpty) {
      return isRequired ? 'Engine number is required' : null;
    }
    if (trimmed.length < 5 || trimmed.length > 25) {
      return 'Engine number must be 5 to 25 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(trimmed)) {
      return 'Engine number may contain only letters and numbers';
    }
    return null;
  }

  /// Indian registration mark, e.g. `MH12AB1234`, `DL1CAA1111`, `KA01A1234`.
  ///
  /// Also accepts the BH series (`24BH1234AA`) introduced for transferable
  /// registrations, which does not fit the older pattern.
  static String? registrationNumber(String? value, {bool isRequired = false}) {
    final String trimmed = (value ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]'),
      '',
    );
    if (trimmed.isEmpty) {
      return isRequired ? 'Registration number is required' : null;
    }
    final bool standard = RegExp(
      r'^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$',
    ).hasMatch(trimmed);
    final bool bharatSeries = RegExp(
      r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$',
    ).hasMatch(trimmed);
    if (!standard && !bharatSeries) {
      return 'Enter a valid registration number (e.g. MH12AB1234)';
    }
    return null;
  }

  /// Odometer reading. Rejects an implausible value and, when the previous
  /// reading is known, rejects one that has gone backwards.
  static String? odometer(String? value, {int? previousReading}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Odometer reading is required';
    }
    final int? reading = int.tryParse(trimmed.replaceAll(',', ''));
    if (reading == null) {
      return 'Enter the odometer reading in kilometres';
    }
    if (reading < 0) {
      return 'Odometer reading cannot be negative';
    }
    if (reading > 999999) {
      return 'Odometer reading looks too high';
    }
    if (previousReading != null && reading < previousReading) {
      return 'Reading cannot be below the last recorded '
          '$previousReading km';
    }
    return null;
  }

  static String? modelYear(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final int? year = int.tryParse(trimmed);
    final int currentYear = DateTime.now().year;
    if (year == null) {
      return 'Enter a four-digit year';
    }
    if (year < 1980 || year > currentYear + 1) {
      return 'Enter a year between 1980 and ${currentYear + 1}';
    }
    return null;
  }

  // --------------------------------------------------------------- amounts

  /// A monetary amount. Rejects negatives by default, matching the
  /// `amount >= 0` CHECK constraints on the financial tables.
  static String? amount(
    String? value, {
    bool isRequired = true,
    bool allowZero = false,
    double? min,
    double? max,
    String field = 'Amount',
  }) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? '$field is required' : null;
    }
    final Decimal? parsed = Decimal.tryParse(
      trimmed.replaceAll(',', '').replaceAll('₹', '').trim(),
    );
    if (parsed == null) {
      return 'Enter a valid $field';
    }
    if (parsed < Decimal.zero) {
      return '$field cannot be negative';
    }
    if (!allowZero && parsed == Decimal.zero) {
      return '$field must be greater than zero';
    }
    if (min != null && parsed.toDouble() < min) {
      return '$field must be at least ${MoneyUtil.format(min)}';
    }
    if (max != null && parsed.toDouble() > max) {
      return '$field cannot exceed ${MoneyUtil.format(max)}';
    }
    // Two decimal places is the storage precision; more would be silently
    // rounded, which on a financial figure should be an explicit rejection.
    if (parsed.scale > 2) {
      return '$field can have at most 2 decimal places';
    }
    return null;
  }

  /// A payment amount checked against what is actually outstanding.
  ///
  /// Overpayment is only legitimate when the surplus is deliberately booked as
  /// a customer advance, which is why the caller must opt in. `record_payment()`
  /// applies the same rule server-side.
  static String? paymentAmount(
    String? value, {
    required double outstanding,
    bool allowAdvance = false,
  }) {
    final String? basic = amount(value, field: 'Payment amount');
    if (basic != null) {
      return basic;
    }
    final Decimal parsed = MoneyUtil.toDecimal(value);
    final Decimal due = MoneyUtil.toDecimal(outstanding);

    if (!allowAdvance && parsed > due) {
      return 'Payment cannot exceed the outstanding '
          '${MoneyUtil.format(outstanding)}';
    }
    return null;
  }

  /// Discount, either absolute or as a percentage of [base].
  static String? discount(
    String? value, {
    required double base,
    bool isPercentage = false,
  }) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final Decimal? parsed = Decimal.tryParse(trimmed.replaceAll(',', ''));
    if (parsed == null) {
      return 'Enter a valid discount';
    }
    if (parsed < Decimal.zero) {
      return 'Discount cannot be negative';
    }
    if (isPercentage) {
      if (parsed > Decimal.fromInt(100)) {
        return 'Discount cannot exceed 100%';
      }
      return null;
    }
    if (parsed > MoneyUtil.toDecimal(base)) {
      return 'Discount cannot exceed ${MoneyUtil.format(base)}';
    }
    return null;
  }

  /// GST rate. Restricted to the statutory slabs, since an arbitrary rate on a
  /// tax invoice is almost always a typo.
  static String? taxRate(String? value, {bool isRequired = false}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? 'Tax rate is required' : null;
    }
    final Decimal? parsed = Decimal.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid tax rate';
    }
    final double rate = parsed.toDouble();
    if (rate < 0 || rate > 100) {
      return 'Tax rate must be between 0 and 100';
    }
    const List<double> gstSlabs = <double>[0, 0.25, 3, 5, 12, 18, 28];
    if (!gstSlabs.contains(rate)) {
      return 'Tax rate should be one of '
          '${gstSlabs.map((double s) => '$s%').join(', ')}';
    }
    return null;
  }

  static String? quantity(String? value, {int min = 1, int? max}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Quantity is required';
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a whole number';
    }
    if (parsed < min) {
      return 'Quantity must be at least $min';
    }
    if (max != null && parsed > max) {
      return 'Only $max available';
    }
    return null;
  }

  static String? percentage(
    String? value, {
    bool isRequired = false,
    String field = 'Percentage',
    double max = 100,
  }) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? '$field is required' : null;
    }
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid $field';
    }
    if (parsed < 0 || parsed > max) {
      return '$field must be between 0 and $max';
    }
    return null;
  }

  // ------------------------------------------------------------------ loan

  /// Annual interest rate on a vehicle loan.
  static String? interestRate(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Interest rate is required';
    }
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter a valid interest rate';
    }
    if (parsed <= 0) {
      return 'Interest rate must be greater than zero';
    }
    if (parsed > 60) {
      return 'Interest rate above 60% per annum is not permitted';
    }
    return null;
  }

  static String? tenureMonths(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Tenure is required';
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter the tenure in whole months';
    }
    if (parsed < 3) {
      return 'Tenure must be at least 3 months';
    }
    if (parsed > 84) {
      return 'Tenure cannot exceed 84 months';
    }
    return null;
  }

  /// Down payment must leave a positive amount to finance.
  static String? downPayment(String? value, {required double vehiclePrice}) {
    final String? basic = amount(value, allowZero: true, field: 'Down payment');
    if (basic != null) {
      return basic;
    }
    final Decimal parsed = MoneyUtil.toDecimal(value);
    final Decimal price = MoneyUtil.toDecimal(vehiclePrice);
    if (parsed >= price) {
      return 'Down payment must be less than the vehicle price; '
          'no finance would be required';
    }
    return null;
  }

  // ------------------------------------------------------------------ dates

  static String? date(
    DateTime? value, {
    bool isRequired = true,
    DateTime? notBefore,
    DateTime? notAfter,
    bool allowFuture = true,
    String field = 'Date',
  }) {
    if (value == null) {
      return isRequired ? '$field is required' : null;
    }
    if (!allowFuture && DateUtil.isFuture(value)) {
      return '$field cannot be in the future';
    }
    if (notBefore != null && value.isBefore(DateUtil.startOfDay(notBefore))) {
      return '$field cannot be before ${DateUtil.format(notBefore)}';
    }
    if (notAfter != null && value.isAfter(DateUtil.endOfDay(notAfter))) {
      return '$field cannot be after ${DateUtil.format(notAfter)}';
    }
    return null;
  }

  /// Validates an ordered pair, e.g. warranty start/end or a report range.
  static String? dateRange({
    required DateTime? start,
    required DateTime? end,
    String startField = 'Start date',
    String endField = 'End date',
  }) {
    if (start == null) {
      return '$startField is required';
    }
    if (end == null) {
      return '$endField is required';
    }
    if (end.isBefore(start)) {
      return '$endField cannot be before $startField';
    }
    return null;
  }

  static String? dateOfBirth(DateTime? value, {int minimumAge = 18}) {
    if (value == null) {
      return null;
    }
    if (DateUtil.isFuture(value)) {
      return 'Date of birth cannot be in the future';
    }
    final int age = DateUtil.ageInYears(value);
    if (age < minimumAge) {
      return 'Customer must be at least $minimumAge years old';
    }
    if (age > 120) {
      return 'Please check the date of birth';
    }
    return null;
  }

  // -------------------------------------------------------------- documents

  /// Codes used in document numbers and master data: uppercase alphanumeric
  /// with hyphens and underscores, which keeps generated numbers URL-safe.
  static String? code(
    String? value, {
    bool isRequired = true,
    int minLength = 2,
    int maxLength = 20,
    String field = 'Code',
  }) {
    final String trimmed = (value ?? '').trim().toUpperCase();
    if (trimmed.isEmpty) {
      return isRequired ? '$field is required' : null;
    }
    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return '$field must be $minLength to $maxLength characters';
    }
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(trimmed)) {
      return '$field may contain only letters, numbers, hyphens '
          'and underscores';
    }
    return null;
  }

  /// A person or business name. Permits the punctuation that genuinely appears
  /// in Indian names and firm names while rejecting control characters and
  /// angle brackets.
  static String? name(
    String? value, {
    bool isRequired = true,
    String field = 'Name',
    int maxLength = 150,
  }) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? '$field is required' : null;
    }
    if (trimmed.length < 2) {
      return '$field must be at least 2 characters';
    }
    if (trimmed.length > maxLength) {
      return '$field must not exceed $maxLength characters';
    }
    if (!RegExp(
      r"^[\p{L}\p{M}0-9 .,'&()/-]+$",
      unicode: true,
    ).hasMatch(trimmed)) {
      return '$field contains characters that are not allowed';
    }
    return null;
  }

  static String? ifscCode(String? value, {bool isRequired = false}) {
    final String trimmed = (value ?? '').trim().toUpperCase();
    if (trimmed.isEmpty) {
      return isRequired ? 'IFSC code is required' : null;
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(trimmed)) {
      return 'Enter a valid IFSC code (e.g. HDFC0001234)';
    }
    return null;
  }

  /// Reference for a non-cash payment. Length rules differ per tender, and a
  /// missing reference makes bank reconciliation impossible.
  static String? paymentReference(
    String? value, {
    required bool isRequired,
    String field = 'Reference number',
  }) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? '$field is required for this payment method' : null;
    }
    if (trimmed.length < 4) {
      return '$field looks too short';
    }
    if (trimmed.length > 50) {
      return '$field must not exceed 50 characters';
    }
    return null;
  }

  static String? url(String? value, {bool isRequired = false}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? 'URL is required' : null;
    }
    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return 'Enter a valid URL including https://';
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return 'Only http and https URLs are supported';
    }
    return null;
  }

  /// Hex colour for a product colour swatch.
  static String? hexColor(String? value, {bool isRequired = true}) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return isRequired ? 'Colour code is required' : null;
    }
    if (!RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$').hasMatch(trimmed)) {
      return 'Enter a hex colour such as #1A73E8';
    }
    return null;
  }
}
