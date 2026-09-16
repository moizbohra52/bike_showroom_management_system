import 'package:bike_showroom_management_system/core/validators/app_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppValidators.phone', () {
    test('accepts a valid Indian mobile number', () {
      expect(AppValidators.phone('9876543210'), isNull);
      expect(AppValidators.phone('6123456789'), isNull);
    });

    test('accepts and normalises the ways numbers get pasted in', () {
      expect(AppValidators.phone('+91 98765 43210'), isNull);
      expect(AppValidators.phone('098765-43210'), isNull);
      expect(AppValidators.phone('(987) 654-3210'), isNull);
    });

    test('rejects wrong length and wrong leading digit', () {
      expect(AppValidators.phone('98765'), isNotNull);
      expect(AppValidators.phone('5876543210'), isNotNull);
      expect(AppValidators.phone('1234567890'), isNotNull);
    });

    test('honours the optional flag', () {
      expect(AppValidators.phone('', isRequired: false), isNull);
      expect(AppValidators.phone(null, isRequired: false), isNull);
      expect(AppValidators.phone(''), isNotNull);
    });

    test('normalisePhone reduces every spelling to the same ten digits', () {
      // The UNIQUE index on (showroom_id, phone) depends on this: two
      // differently formatted entries of one number must collide.
      const List<String> spellings = <String>[
        '9876543210',
        '+919876543210',
        '09876543210',
        '+91 98765 43210',
        '98765-43210',
        '91-9876543210',
      ];
      for (final String spelling in spellings) {
        expect(
          AppValidators.normalisePhone(spelling),
          '9876543210',
          reason: 'failed to normalise "$spelling"',
        );
      }
    });
  });

  group('AppValidators.email', () {
    test('accepts realistic addresses', () {
      expect(AppValidators.email('rider@example.com'), isNull);
      expect(AppValidators.email('first.last+tag@sub.example.co.in'), isNull);
    });

    test('rejects malformed addresses', () {
      expect(AppValidators.email('no-at-sign'), isNotNull);
      expect(AppValidators.email('@example.com'), isNotNull);
      expect(AppValidators.email('user@'), isNotNull);
      expect(AppValidators.email('user@example'), isNotNull);
      expect(AppValidators.email('user@.com'), isNotNull);
      expect(AppValidators.email('user name@example.com'), isNotNull);
    });
  });

  group('AppValidators.gstNumber', () {
    test('accepts GSTINs that satisfy the mod-36 checksum', () {
      // Verified against GSTN's documented algorithm. 27AAPFU0939F1ZV is the
      // canonical example published with the specification.
      expect(AppValidators.gstNumber('27AAPFU0939F1ZV'), isNull);
      expect(AppValidators.gstNumber('27AAACR5055K1Z7'), isNull);
      expect(AppValidators.gstNumber('27AAACT2727Q1ZW'), isNull);
    });

    test('normalises case before validating', () {
      expect(AppValidators.gstNumber('27aapfu0939f1zv'), isNull);
    });

    test('rejects a single mistyped character via the checksum', () {
      // This is the whole point of validating the checksum: a transposition
      // that still matches the structural pattern is still caught.
      expect(AppValidators.gstNumber('27AAPFU0939F1ZX'), isNotNull);
      expect(AppValidators.gstNumber('27AAPFU0938F1ZV'), isNotNull);
    });

    test('rejects structurally wrong values', () {
      expect(AppValidators.gstNumber('27AAPFU0939F1Z'), isNotNull);
      expect(AppValidators.gstNumber('27AAPFU0939F1AV'), isNotNull);
      expect(AppValidators.gstNumber('991APFU0939F1ZV'), isNotNull);
    });

    test('rejects an out-of-range state code', () {
      expect(AppValidators.gstNumber('99AAPFU0939F1ZV'), isNotNull);
      expect(AppValidators.gstNumber('00AAPFU0939F1ZV'), isNotNull);
    });

    test('is optional unless demanded', () {
      expect(AppValidators.gstNumber(''), isNull);
      expect(AppValidators.gstNumber('', isRequired: true), isNotNull);
    });
  });

  group('AppValidators.panNumber', () {
    test('accepts a well-formed PAN', () {
      expect(AppValidators.panNumber('ABCPE1234F'), isNull);
      expect(AppValidators.panNumber('AAACR5055K'), isNull);
    });

    test('rejects an invalid holder-type character', () {
      // 4th character must be a recognised holder type; X is not.
      expect(AppValidators.panNumber('ABCXE1234F'), isNotNull);
    });

    test('rejects structural errors', () {
      expect(AppValidators.panNumber('ABCP1234F'), isNotNull);
      expect(AppValidators.panNumber('ABCPE12345'), isNotNull);
      expect(AppValidators.panNumber('12345E1234F'), isNotNull);
    });
  });

  group('AppValidators.chassisNumber', () {
    test('accepts a realistic chassis number', () {
      expect(AppValidators.chassisNumber('ME4JC509KLT123456'), isNull);
      expect(AppValidators.chassisNumber('MBLHA10AZJHF12345'), isNull);
    });

    test('rejects I, O and Q which manufacturers do not use', () {
      // These are the classic transcription errors for 1 and 0.
      expect(AppValidators.chassisNumber('ME4JC5O9KLT123456'), isNotNull);
      expect(AppValidators.chassisNumber('ME4JC5I9KLT123456'), isNotNull);
      expect(AppValidators.chassisNumber('ME4JC5Q9KLT123456'), isNotNull);
    });

    test('enforces a plausible length', () {
      expect(AppValidators.chassisNumber('ABC123'), isNotNull);
      expect(AppValidators.chassisNumber('A' * 30), isNotNull);
    });
  });

  group('AppValidators.registrationNumber', () {
    test('accepts standard state registration marks', () {
      expect(AppValidators.registrationNumber('MH12AB1234'), isNull);
      expect(AppValidators.registrationNumber('DL1CAA1111'), isNull);
      expect(AppValidators.registrationNumber('KA01A1234'), isNull);
      expect(AppValidators.registrationNumber('TN09BZ9999'), isNull);
    });

    test('accepts the Bharat (BH) series', () {
      expect(AppValidators.registrationNumber('24BH1234AA'), isNull);
      expect(AppValidators.registrationNumber('22BH5678A'), isNull);
    });

    test('tolerates separators used on paperwork', () {
      expect(AppValidators.registrationNumber('MH 12 AB 1234'), isNull);
      expect(AppValidators.registrationNumber('MH-12-AB-1234'), isNull);
    });

    test('rejects malformed marks', () {
      expect(AppValidators.registrationNumber('1234MH12'), isNotNull);
      expect(AppValidators.registrationNumber('MHABCD1234'), isNotNull);
    });
  });

  group('AppValidators.amount', () {
    test('rejects negatives and enforces currency precision', () {
      expect(AppValidators.amount('1000'), isNull);
      expect(AppValidators.amount('1000.50'), isNull);
      expect(AppValidators.amount('-100'), isNotNull);
      expect(AppValidators.amount('1000.555'), isNotNull);
    });

    test('distinguishes zero from empty', () {
      expect(AppValidators.amount('0'), isNotNull);
      expect(AppValidators.amount('0', allowZero: true), isNull);
      expect(AppValidators.amount(''), isNotNull);
      expect(AppValidators.amount('', isRequired: false), isNull);
    });

    test('strips grouping separators and the currency symbol', () {
      expect(AppValidators.amount('1,50,000'), isNull);
      expect(AppValidators.amount('₹1,50,000.00'), isNull);
    });

    test('honours explicit bounds', () {
      expect(AppValidators.amount('50', min: 100), isNotNull);
      expect(AppValidators.amount('500', max: 100), isNotNull);
    });
  });

  group('AppValidators.paymentAmount', () {
    test('blocks overpayment unless booked as an advance', () {
      expect(AppValidators.paymentAmount('5000', outstanding: 10000), isNull);
      expect(
        AppValidators.paymentAmount('15000', outstanding: 10000),
        isNotNull,
      );
      expect(
        AppValidators.paymentAmount(
          '15000',
          outstanding: 10000,
          allowAdvance: true,
        ),
        isNull,
      );
    });

    test('allows settling the exact outstanding amount', () {
      expect(AppValidators.paymentAmount('10000', outstanding: 10000), isNull);
    });
  });

  group('AppValidators.taxRate', () {
    test('accepts statutory GST slabs only', () {
      for (final String slab in <String>['0', '5', '12', '18', '28']) {
        expect(AppValidators.taxRate(slab), isNull, reason: 'slab $slab');
      }
      expect(AppValidators.taxRate('17'), isNotNull);
      expect(AppValidators.taxRate('101'), isNotNull);
      expect(AppValidators.taxRate('-5'), isNotNull);
    });
  });

  group('AppValidators.discount', () {
    test('caps an absolute discount at the base amount', () {
      expect(AppValidators.discount('500', base: 1000), isNull);
      expect(AppValidators.discount('1500', base: 1000), isNotNull);
    });

    test('caps a percentage discount at 100', () {
      expect(
        AppValidators.discount('10', base: 1000, isPercentage: true),
        isNull,
      );
      expect(
        AppValidators.discount('150', base: 1000, isPercentage: true),
        isNotNull,
      );
    });
  });

  group('AppValidators loan fields', () {
    test('interestRate stays within a lawful band', () {
      expect(AppValidators.interestRate('9.5'), isNull);
      expect(AppValidators.interestRate('0'), isNotNull);
      expect(AppValidators.interestRate('75'), isNotNull);
    });

    test('tenureMonths stays within 3 to 84 months', () {
      expect(AppValidators.tenureMonths('36'), isNull);
      expect(AppValidators.tenureMonths('2'), isNotNull);
      expect(AppValidators.tenureMonths('120'), isNotNull);
    });

    test('downPayment must leave something to finance', () {
      expect(AppValidators.downPayment('20000', vehiclePrice: 100000), isNull);
      expect(
        AppValidators.downPayment('100000', vehiclePrice: 100000),
        isNotNull,
      );
    });
  });

  group('AppValidators.odometer', () {
    test('rejects a reading that has gone backwards', () {
      // A service job cannot record fewer kilometres than the last visit.
      expect(AppValidators.odometer('15000', previousReading: 12000), isNull);
      expect(
        AppValidators.odometer('11000', previousReading: 12000),
        isNotNull,
      );
    });

    test('rejects implausible values', () {
      expect(AppValidators.odometer('-5'), isNotNull);
      expect(AppValidators.odometer('1000000'), isNotNull);
      expect(AppValidators.odometer('abc'), isNotNull);
    });
  });

  group('AppValidators.pincode', () {
    test('requires six digits not starting with zero', () {
      expect(AppValidators.pincode('400001'), isNull);
      expect(AppValidators.pincode('040001'), isNotNull);
      expect(AppValidators.pincode('40001'), isNotNull);
    });
  });

  group('AppValidators.ifscCode', () {
    test('enforces the four-letter bank code and zero separator', () {
      expect(AppValidators.ifscCode('HDFC0001234'), isNull);
      expect(AppValidators.ifscCode('HDFC1001234'), isNotNull);
      expect(AppValidators.ifscCode('HDF00001234'), isNotNull);
    });
  });

  group('AppValidators.dateRange', () {
    test('rejects an end before the start', () {
      expect(
        AppValidators.dateRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 12, 31),
        ),
        isNull,
      );
      expect(
        AppValidators.dateRange(
          start: DateTime(2026, 12, 31),
          end: DateTime(2026, 1, 1),
        ),
        isNotNull,
      );
    });
  });

  group('AppValidators.password', () {
    test('enforces length and character classes', () {
      expect(AppValidators.password('Str0ngPass'), isNull);
      expect(AppValidators.password('short1A'), isNotNull);
      expect(AppValidators.password('alllowercase1'), isNotNull);
      expect(AppValidators.password('ALLUPPERCASE1'), isNotNull);
      expect(AppValidators.password('NoDigitsHere'), isNotNull);
    });

    test('confirmPassword compares against the original', () {
      expect(AppValidators.confirmPassword('Str0ngPass', 'Str0ngPass'), isNull);
      expect(
        AppValidators.confirmPassword('Str0ngPass', 'Different1'),
        isNotNull,
      );
    });
  });

  group('AppValidators.compose and optional', () {
    test('compose returns the first failure', () {
      final String? error = AppValidators.compose(
        '',
        <String? Function(String?)>[
          AppValidators.requiredText,
          (String? v) => AppValidators.email(v),
        ],
      );
      expect(error, contains('required'));
    });

    test('optional skips validation for an empty value', () {
      final String? Function(String?) check = AppValidators.optional(
        (String? v) => AppValidators.email(v),
      );
      expect(check(''), isNull);
      expect(check(null), isNull);
      expect(check('bad'), isNotNull);
    });
  });

  group('AppValidators.name', () {
    test('accepts names and firm names with real punctuation', () {
      expect(AppValidators.name('Rajesh Kumar'), isNull);
      expect(AppValidators.name("D'Souza Motors"), isNull);
      expect(AppValidators.name('Sharma & Sons (Pvt.) Ltd.'), isNull);
      expect(AppValidators.name('Ramesh S/o Suresh'), isNull);
    });

    test('rejects markup characters', () {
      expect(AppValidators.name('<script>alert(1)</script>'), isNotNull);
    });
  });
}
