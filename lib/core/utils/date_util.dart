import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:intl/intl.dart';

/// A closed date range, inclusive of both ends.
///
/// Every list filter and report in the application takes one of these rather
/// than a loose pair of nullable dates, so that "from after to" is impossible
/// to express.
class DateRange {
  DateRange({required DateTime start, required DateTime end})
    : start = DateUtil.startOfDay(start.isAfter(end) ? end : start),
      end = DateUtil.endOfDay(start.isAfter(end) ? start : end);

  /// Today only.
  factory DateRange.today() {
    final DateTime now = DateTime.now();
    return DateRange(start: now, end: now);
  }

  factory DateRange.yesterday() {
    final DateTime day = DateTime.now().subtract(const Duration(days: 1));
    return DateRange(start: day, end: day);
  }

  /// Monday through Sunday of the current week.
  factory DateRange.thisWeek() {
    final DateTime now = DateTime.now();
    final DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    return DateRange(start: monday, end: monday.add(const Duration(days: 6)));
  }

  factory DateRange.thisMonth() {
    final DateTime now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month),
      end: DateUtil.lastDayOfMonth(now),
    );
  }

  factory DateRange.lastMonth() {
    final DateTime now = DateTime.now();
    final DateTime previous = DateTime(now.year, now.month - 1);
    return DateRange(start: previous, end: DateUtil.lastDayOfMonth(previous));
  }

  factory DateRange.thisQuarter() {
    final DateTime now = DateTime.now();
    final int firstMonthOfQuarter = ((now.month - 1) ~/ 3) * 3 + 1;
    final DateTime start = DateTime(now.year, firstMonthOfQuarter);
    return DateRange(
      start: start,
      end: DateUtil.lastDayOfMonth(DateTime(now.year, firstMonthOfQuarter + 2)),
    );
  }

  /// Indian financial year containing today: 1 April to 31 March.
  factory DateRange.thisFinancialYear() {
    final DateTime now = DateTime.now();
    final int startYear = now.month >= 4 ? now.year : now.year - 1;
    return DateRange(
      start: DateTime(startYear, 4),
      end: DateTime(startYear + 1, 3, 31),
    );
  }

  factory DateRange.lastFinancialYear() {
    final DateTime now = DateTime.now();
    final int startYear = now.month >= 4 ? now.year - 1 : now.year - 2;
    return DateRange(
      start: DateTime(startYear, 4),
      end: DateTime(startYear + 1, 3, 31),
    );
  }

  /// The last [days] days, ending today.
  factory DateRange.lastDays(int days) {
    final DateTime now = DateTime.now();
    return DateRange(
      start: now.subtract(Duration(days: days - 1)),
      end: now,
    );
  }

  /// The next [days] days, starting today. Used for upcoming EMI and service.
  factory DateRange.nextDays(int days) {
    final DateTime now = DateTime.now();
    return DateRange(
      start: now,
      end: now.add(Duration(days: days - 1)),
    );
  }

  final DateTime start;
  final DateTime end;

  int get dayCount => end.difference(start).inDays + 1;

  bool contains(DateTime value) =>
      !value.isBefore(start) && !value.isAfter(end);

  /// ISO date strings for a PostgREST `gte`/`lte` filter pair.
  String get startIso => DateUtil.toIsoDate(start);
  String get endIso => DateUtil.toIsoDate(end);

  /// Full timestamps, for columns typed `timestamptz`.
  String get startTimestamp => start.toUtc().toIso8601String();
  String get endTimestamp => end.toUtc().toIso8601String();

  String get label => '${DateUtil.format(start)} - ${DateUtil.format(end)}';

  DateRange copyWith({DateTime? start, DateTime? end}) =>
      DateRange(start: start ?? this.start, end: end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DateRange($startIso..$endIso)';
}

/// Named presets offered by the filter bar.
enum DateRangePreset {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  last7Days('Last 7 Days'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  last30Days('Last 30 Days'),
  thisQuarter('This Quarter'),
  thisFinancialYear('This Financial Year'),
  lastFinancialYear('Last Financial Year'),
  custom('Custom Range');

  const DateRangePreset(this.label);

  final String label;

  /// Resolves the preset against the current date. [custom] has no fixed
  /// range and returns null so the caller can open a picker.
  DateRange? resolve() {
    switch (this) {
      case DateRangePreset.today:
        return DateRange.today();
      case DateRangePreset.yesterday:
        return DateRange.yesterday();
      case DateRangePreset.thisWeek:
        return DateRange.thisWeek();
      case DateRangePreset.last7Days:
        return DateRange.lastDays(7);
      case DateRangePreset.thisMonth:
        return DateRange.thisMonth();
      case DateRangePreset.lastMonth:
        return DateRange.lastMonth();
      case DateRangePreset.last30Days:
        return DateRange.lastDays(30);
      case DateRangePreset.thisQuarter:
        return DateRange.thisQuarter();
      case DateRangePreset.thisFinancialYear:
        return DateRange.thisFinancialYear();
      case DateRangePreset.lastFinancialYear:
        return DateRange.lastFinancialYear();
      case DateRangePreset.custom:
        return null;
    }
  }
}

/// Date parsing, formatting and business-calendar arithmetic.
class DateUtil {
  const DateUtil._();

  static final DateFormat _display = DateFormat(AppConstants.dateFormat);
  static final DateFormat _input = DateFormat(AppConstants.dateInputFormat);
  static final DateFormat _dateTime = DateFormat(AppConstants.dateTimeFormat);
  static final DateFormat _time = DateFormat(AppConstants.timeFormat);
  static final DateFormat _monthYear = DateFormat(AppConstants.monthYearFormat);
  static final DateFormat _iso = DateFormat(AppConstants.isoDateFormat);

  // -------------------------------------------------------------- boundaries

  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// End of day at millisecond resolution, which is what `timestamptz`
  /// comparisons need to include everything stamped during that day.
  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  static DateTime firstDayOfMonth(DateTime value) =>
      DateTime(value.year, value.month);

  /// Last day of [value]'s month. Day 0 of the following month, which handles
  /// 28/29/30/31 and leap years without a lookup table.
  static DateTime lastDayOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0, 23, 59, 59, 999);

  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime? value) => isSameDay(value, DateTime.now());

  static bool isPast(DateTime? value) {
    if (value == null) {
      return false;
    }
    return value.isBefore(startOfDay(DateTime.now()));
  }

  static bool isFuture(DateTime? value) {
    if (value == null) {
      return false;
    }
    return value.isAfter(endOfDay(DateTime.now()));
  }

  // ------------------------------------------------------------- arithmetic

  /// Adds [months] calendar months, clamping the day to the target month's
  /// length.
  ///
  /// This is the rule EMI schedules use: a loan starting 31 January has its
  /// second instalment on 28 (or 29) February, not on 3 March. Dart's
  /// `DateTime` constructor would roll over, so the clamp is explicit.
  /// `generate_emi_schedule()` implements the identical rule in SQL.
  static DateTime addMonths(DateTime value, int months) {
    // Zero-based month index, which may go negative for a backwards offset.
    final int targetMonthIndex = value.month - 1 + months;

    // Floor division is required, not `~/`: Dart truncates `~/` toward zero
    // while `%` is always non-negative, and mixing the two loses a year for
    // negative offsets (Jan minus one month would land in December of the
    // *same* year).
    final int year = value.year + (targetMonthIndex / 12).floor();
    final int month = (targetMonthIndex % 12) + 1;

    final int daysInTargetMonth = DateTime(year, month + 1, 0).day;
    final int day = value.day > daysInTargetMonth
        ? daysInTargetMonth
        : value.day;

    return DateTime(year, month, day, value.hour, value.minute, value.second);
  }

  static DateTime addYears(DateTime value, int years) =>
      addMonths(value, years * 12);

  /// Whole calendar months between two dates, ignoring the time of day.
  static int monthsBetween(DateTime from, DateTime to) {
    int months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) {
      months -= 1;
    }
    return months;
  }

  /// Whole days between two dates, counted on calendar boundaries so that a
  /// difference across a DST change or a late-evening timestamp does not
  /// silently lose a day.
  static int daysBetween(DateTime from, DateTime to) =>
      startOfDay(to).difference(startOfDay(from)).inDays;

  /// Days until [value]; negative when it has already passed.
  static int daysUntil(DateTime? value) {
    if (value == null) {
      return 0;
    }
    return daysBetween(DateTime.now(), value);
  }

  /// Days by which [value] is overdue; zero when not yet due.
  static int daysOverdue(DateTime? value) {
    final int until = daysUntil(value);
    return until < 0 ? -until : 0;
  }

  /// Whether [expiryDate] falls inside the warning window used for insurance
  /// and warranty tiles.
  static bool isExpiringSoon(
    DateTime? expiryDate, {
    int withinDays = AppConstants.expiryWarningDays,
  }) {
    if (expiryDate == null) {
      return false;
    }
    final int days = daysUntil(expiryDate);
    return days >= 0 && days <= withinDays;
  }

  static bool isExpired(DateTime? expiryDate) {
    if (expiryDate == null) {
      return false;
    }
    return daysUntil(expiryDate) < 0;
  }

  /// Age in completed years, for a customer date of birth.
  static int ageInYears(DateTime birthDate) {
    final DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  /// Indian financial year label for a date, e.g. `2025-26`.
  ///
  /// Used in document number prefixes, which must reset each financial year.
  static String financialYearLabel(DateTime value) {
    final int startYear = value.month >= 4 ? value.year : value.year - 1;
    final String endSuffix = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return '$startYear-$endSuffix';
  }

  /// Short financial-year code for a document number, e.g. `2526`.
  static String financialYearCode(DateTime value) {
    final int startYear = value.month >= 4 ? value.year : value.year - 1;
    final String start = (startYear % 100).toString().padLeft(2, '0');
    final String end = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return '$start$end';
  }

  // -------------------------------------------------------------- formatting

  /// `12 Mar 2026`
  static String format(DateTime? value) =>
      value == null ? '-' : _display.format(value);

  /// `12/03/2026` — matches what the text field accepts.
  static String formatInput(DateTime? value) =>
      value == null ? '' : _input.format(value);

  /// `12 Mar 2026, 04:30 PM`
  static String formatDateTime(DateTime? value) =>
      value == null ? '-' : _dateTime.format(value.toLocal());

  /// `04:30 PM`
  static String formatTime(DateTime? value) =>
      value == null ? '-' : _time.format(value.toLocal());

  /// `Mar 2026`
  static String formatMonthYear(DateTime? value) =>
      value == null ? '-' : _monthYear.format(value);

  /// `2026-03-12` — the wire format for a `date` column.
  static String toIsoDate(DateTime value) => _iso.format(value);

  static String? toIsoDateOrNull(DateTime? value) =>
      value == null ? null : toIsoDate(value);

  /// Full UTC timestamp for a `timestamptz` column.
  static String toTimestamp(DateTime value) => value.toUtc().toIso8601String();

  static String? toTimestampOrNull(DateTime? value) =>
      value == null ? null : toTimestamp(value);

  /// Relative phrasing for timelines and notification lists.
  static String relative(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(value);

    if (difference.isNegative) {
      final Duration ahead = difference.abs();
      if (ahead.inMinutes < 1) {
        return 'in a moment';
      }
      if (ahead.inHours < 1) {
        return 'in ${ahead.inMinutes}m';
      }
      if (ahead.inDays < 1) {
        return 'in ${ahead.inHours}h';
      }
      if (ahead.inDays == 1) {
        return 'tomorrow';
      }
      if (ahead.inDays < 30) {
        return 'in ${ahead.inDays} days';
      }
      return format(value);
    }

    if (difference.inSeconds < 60) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays == 1) {
      return 'yesterday';
    }
    if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    }
    return format(value);
  }

  /// Human phrasing of a due date, with overdue emphasised.
  static String dueLabel(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final int days = daysUntil(value);
    if (days == 0) {
      return 'Due today';
    }
    if (days == 1) {
      return 'Due tomorrow';
    }
    if (days > 0) {
      return 'Due in $days days';
    }
    final int overdue = -days;
    return overdue == 1 ? 'Overdue by 1 day' : 'Overdue by $overdue days';
  }

  // ----------------------------------------------------------------- parsing

  /// Tolerant parser for values arriving from the database or a form.
  ///
  /// PostgreSQL `date` columns arrive as `2026-03-12` and `timestamptz` as an
  /// ISO-8601 string; text fields supply `12/03/2026`. All three are accepted,
  /// and anything else yields null rather than throwing.
  static DateTime? parse(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    final String raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    final DateTime? iso = DateTime.tryParse(raw);
    if (iso != null) {
      return iso;
    }
    try {
      return _input.parseStrict(raw);
    } on FormatException {
      // Fall through to the dash-separated variant below.
    }
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(raw);
    } on FormatException {
      return null;
    }
  }

  /// Parses a `timestamptz` and converts to local time for display.
  static DateTime? parseLocal(Object? value) => parse(value)?.toLocal();

  /// Combines a date with a `HH:mm:ss` time string, as stored by
  /// `reminders.reminder_time`.
  static DateTime combineDateAndTime(DateTime date, String? time) {
    if (time == null || time.isEmpty) {
      return startOfDay(date);
    }
    final List<String> parts = time.split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final int second = parts.length > 2
        ? int.tryParse(parts[2].split('.').first) ?? 0
        : 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  /// `HH:mm:ss` for a `time` column.
  static String toTimeString(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}
