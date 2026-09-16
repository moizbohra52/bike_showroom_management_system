import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateUtil.addMonths', () {
    test('clamps to the last day of a shorter target month', () {
      // The EMI rule: a loan starting 31 Jan bills on 28 Feb, not 3 Mar.
      expect(
        DateUtil.addMonths(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 28),
      );
      expect(
        DateUtil.addMonths(DateTime(2026, 3, 31), 1),
        DateTime(2026, 4, 30),
      );
      expect(
        DateUtil.addMonths(DateTime(2026, 8, 31), 1),
        DateTime(2026, 9, 30),
      );
    });

    test('honours February in a leap year', () {
      expect(
        DateUtil.addMonths(DateTime(2028, 1, 31), 1),
        DateTime(2028, 2, 29),
      );
    });

    test('rolls the year over correctly', () {
      expect(
        DateUtil.addMonths(DateTime(2026, 11, 15), 3),
        DateTime(2027, 2, 15),
      );
      expect(
        DateUtil.addMonths(DateTime(2026, 12, 1), 12),
        DateTime(2027, 12, 1),
      );
    });

    test('handles negative offsets', () {
      expect(
        DateUtil.addMonths(DateTime(2026, 1, 15), -1),
        DateTime(2025, 12, 15),
      );
      expect(
        DateUtil.addMonths(DateTime(2026, 3, 31), -1),
        DateTime(2026, 2, 28),
      );
      expect(
        DateUtil.addMonths(DateTime(2026, 1, 10), -13),
        DateTime(2024, 12, 10),
      );
    });

    test('a 36-month schedule from month-end never drifts past month-end', () {
      final DateTime start = DateTime(2026, 1, 31);
      for (int month = 1; month <= 36; month++) {
        final DateTime due = DateUtil.addMonths(start, month);
        final int lastDay = DateTime(due.year, due.month + 1, 0).day;
        expect(
          due.day,
          lessThanOrEqualTo(lastDay),
          reason: 'instalment $month landed on an invalid day',
        );
        // Either the 31st, or clamped to that month's final day.
        expect(due.day == 31 || due.day == lastDay, isTrue);
      }
    });
  });

  group('DateUtil.monthsBetween', () {
    test('counts only completed months', () {
      expect(
        DateUtil.monthsBetween(DateTime(2026, 1, 15), DateTime(2026, 4, 15)),
        3,
      );
      expect(
        DateUtil.monthsBetween(DateTime(2026, 1, 15), DateTime(2026, 4, 14)),
        2,
      );
      expect(
        DateUtil.monthsBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)),
        12,
      );
    });
  });

  group('DateUtil.lastDayOfMonth', () {
    test('resolves month length without a lookup table', () {
      expect(DateUtil.lastDayOfMonth(DateTime(2026, 2, 10)).day, 28);
      expect(DateUtil.lastDayOfMonth(DateTime(2028, 2, 10)).day, 29);
      expect(DateUtil.lastDayOfMonth(DateTime(2026, 4, 10)).day, 30);
      expect(DateUtil.lastDayOfMonth(DateTime(2026, 12, 10)).day, 31);
    });
  });

  group('DateUtil financial year', () {
    test('runs April to March', () {
      expect(DateUtil.financialYearLabel(DateTime(2026, 4, 1)), '2026-27');
      expect(DateUtil.financialYearLabel(DateTime(2026, 3, 31)), '2025-26');
      expect(DateUtil.financialYearLabel(DateTime(2026, 12, 31)), '2026-27');
      expect(DateUtil.financialYearLabel(DateTime(2027, 1, 1)), '2026-27');
    });

    test('produces a compact code for document numbering', () {
      expect(DateUtil.financialYearCode(DateTime(2026, 4, 1)), '2627');
      expect(DateUtil.financialYearCode(DateTime(2026, 3, 31)), '2526');
    });
  });

  group('DateUtil.parse', () {
    test('accepts every format the system actually receives', () {
      // PostgreSQL `date`
      expect(DateUtil.parse('2026-03-12'), DateTime(2026, 3, 12));
      // Text field
      expect(DateUtil.parse('12/03/2026'), DateTime(2026, 3, 12));
      // Dash variant
      expect(DateUtil.parse('12-03-2026'), DateTime(2026, 3, 12));
      // Pass-through
      expect(DateUtil.parse(DateTime(2026, 3, 12)), DateTime(2026, 3, 12));
    });

    test('returns null instead of throwing on unusable input', () {
      expect(DateUtil.parse(null), isNull);
      expect(DateUtil.parse(''), isNull);
      expect(DateUtil.parse('not a date'), isNull);
      expect(DateUtil.parse('45/45/2026'), isNull);
    });

    test('round-trips a timestamptz string', () {
      final DateTime original = DateTime.utc(2026, 3, 12, 10, 30);
      final String wire = DateUtil.toTimestamp(original);
      expect(DateUtil.parse(wire)?.toUtc(), original);
    });
  });

  group('DateRange', () {
    test('normalises a reversed pair rather than accepting it', () {
      final DateRange range = DateRange(
        start: DateTime(2026, 3, 20),
        end: DateTime(2026, 3, 10),
      );
      expect(range.startIso, '2026-03-10');
      expect(range.endIso, '2026-03-20');
      expect(range.start.isBefore(range.end), isTrue);
    });

    test('covers the whole of the final day', () {
      final DateRange range = DateRange.today();
      expect(range.start.hour, 0);
      expect(range.end.hour, 23);
      expect(range.end.minute, 59);
      // A record stamped late in the evening must fall inside "today".
      final DateTime now = DateTime.now();
      expect(
        range.contains(DateTime(now.year, now.month, now.day, 22, 45)),
        isTrue,
      );
    });

    test('dayCount is inclusive of both ends', () {
      expect(DateRange.today().dayCount, 1);
      expect(DateRange.lastDays(7).dayCount, 7);
      expect(
        DateRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 31),
        ).dayCount,
        31,
      );
    });

    test('financial year preset spans 1 April to 31 March', () {
      final DateRange range = DateRange.thisFinancialYear();
      expect(range.start.month, 4);
      expect(range.start.day, 1);
      expect(range.end.month, 3);
      expect(range.end.day, 31);
      expect(range.end.year, range.start.year + 1);
    });

    test('every non-custom preset resolves to a usable range', () {
      for (final DateRangePreset preset in DateRangePreset.values) {
        final DateRange? resolved = preset.resolve();
        if (preset == DateRangePreset.custom) {
          expect(resolved, isNull);
        } else {
          expect(resolved, isNotNull, reason: '${preset.name} did not resolve');
          expect(resolved!.start.isBefore(resolved.end), isTrue);
        }
      }
    });
  });

  group('DateUtil expiry helpers', () {
    test('classifies expiring-soon and expired correctly', () {
      final DateTime now = DateTime.now();
      expect(
        DateUtil.isExpiringSoon(now.add(const Duration(days: 10))),
        isTrue,
      );
      expect(
        DateUtil.isExpiringSoon(now.add(const Duration(days: 200))),
        isFalse,
      );
      expect(
        DateUtil.isExpiringSoon(now.subtract(const Duration(days: 5))),
        isFalse,
        reason: 'already expired is not "expiring soon"',
      );
      expect(DateUtil.isExpired(now.subtract(const Duration(days: 5))), isTrue);
      expect(DateUtil.isExpired(now.add(const Duration(days: 5))), isFalse);
      expect(DateUtil.isExpired(null), isFalse);
    });

    test('dueLabel phrases overdue separately', () {
      final DateTime now = DateTime.now();
      expect(DateUtil.dueLabel(now), 'Due today');
      expect(
        DateUtil.dueLabel(now.add(const Duration(days: 1))),
        'Due tomorrow',
      );
      expect(
        DateUtil.dueLabel(now.subtract(const Duration(days: 1))),
        'Overdue by 1 day',
      );
      expect(
        DateUtil.dueLabel(now.subtract(const Duration(days: 9))),
        'Overdue by 9 days',
      );
    });
  });

  group('DateUtil.combineDateAndTime', () {
    test('merges a date with a HH:mm:ss reminder time', () {
      expect(
        DateUtil.combineDateAndTime(DateTime(2026, 3, 12), '09:30:00'),
        DateTime(2026, 3, 12, 9, 30),
      );
      expect(
        DateUtil.combineDateAndTime(DateTime(2026, 3, 12), '14:05'),
        DateTime(2026, 3, 12, 14, 5),
      );
      expect(
        DateUtil.combineDateAndTime(DateTime(2026, 3, 12), null),
        DateTime(2026, 3, 12),
      );
    });
  });
}
