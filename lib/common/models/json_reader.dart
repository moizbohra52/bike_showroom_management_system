import 'dart:convert';

import 'package:bike_showroom_management_system/core/utils/date_util.dart';

/// Defensive accessors for a JSON row.
///
/// ## Why every model uses this instead of direct casts
///
/// Rows reach the client from three sources with subtly different typing, and
/// a direct cast that works against one fails against another:
///
///  * PostgREST encodes `numeric` as a **string** to avoid the precision loss
///    of a JSON double, so `row['total_amount'] as double` throws.
///  * `int` and `double` are interchangeable in JSON, so a whole-number
///    `numeric` may arrive as `5` where `5.0` was expected.
///  * The local Hive cache returns `Map<dynamic, dynamic>` after a disk round
///    trip, so a nested object is not a `Map<String, dynamic>`.
///  * An embedded PostgREST relation is a list for a to-many join but a single
///    object for a to-one join.
///
/// Reading through this class means one malformed or unexpected field yields a
/// null or a default rather than an exception that takes down a whole list
/// screen.
extension type JsonReader(Map<String, Object?> row) {
  /// Raw value, or null when absent.
  Object? operator [](String key) => row[key];

  bool has(String key) => row.containsKey(key) && row[key] != null;

  // ------------------------------------------------------------------ scalars

  String? stringOrNull(String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    return value.toString();
  }

  String string(String key, {String fallback = ''}) =>
      stringOrNull(key) ?? fallback;

  /// Required string. Throws when absent, which is correct for a primary key:
  /// a row without an `id` is a bug worth surfacing, not a null to paper over.
  String requireString(String key) {
    final String? value = stringOrNull(key);
    if (value == null) {
      throw FormatException(
        'Required field "$key" was missing from the row',
        row.toString(),
      );
    }
    return value;
  }

  int? intOrNull(String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  int integer(String key, {int fallback = 0}) => intOrNull(key) ?? fallback;

  /// Numeric value as a double.
  ///
  /// Handles the PostgREST string encoding of `numeric`. For arithmetic on
  /// money, prefer [decimalString] and hand it to `MoneyUtil`, which keeps
  /// exact precision; this is for display and for totals already computed
  /// server-side.
  double? doubleOrNull(String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim());
  }

  double money(String key, {double fallback = 0}) =>
      doubleOrNull(key) ?? fallback;

  /// The unparsed numeric text, preserving full precision for exact decimal
  /// arithmetic.
  String? decimalString(String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  bool? boolOrNull(String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final String text = value.toString().toLowerCase().trim();
    if (text == 'true' || text == 't' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == 'f' || text == '0' || text == 'no') {
      return false;
    }
    return null;
  }

  bool boolean(String key, {bool fallback = false}) =>
      boolOrNull(key) ?? fallback;

  // -------------------------------------------------------------------- dates

  DateTime? dateOrNull(String key) => DateUtil.parse(row[key]);

  /// A `timestamptz`, converted to local time for display.
  DateTime? timestampOrNull(String key) => DateUtil.parse(row[key])?.toLocal();

  DateTime date(String key, {DateTime? fallback}) =>
      dateOrNull(key) ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);

  // ------------------------------------------------------------------ nested

  /// A nested object, normalising Hive's `Map<dynamic, dynamic>`.
  ///
  /// Also unwraps a single-element list, because PostgREST returns a to-one
  /// embedded relation as a list when the foreign key is not provably unique.
  Map<String, Object?>? objectOrNull(String key) {
    final Object? value = row[key];
    if (value == null) {
      return null;
    }
    if (value is Map) {
      return _coerceMap(value);
    }
    if (value is List && value.isNotEmpty) {
      final Object? first = value.first;
      if (first is Map) {
        return _coerceMap(first);
      }
    }
    if (value is String && value.isNotEmpty) {
      // A `jsonb` column can arrive as text depending on the select.
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map) {
          return _coerceMap(decoded);
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// A nested array of objects. Returns empty rather than null so callers can
  /// iterate without a null check.
  List<Map<String, Object?>> objectList(String key) {
    final Object? value = row[key];
    if (value == null) {
      return const <Map<String, Object?>>[];
    }
    if (value is List) {
      return value
          .whereType<Map<Object?, Object?>>()
          .map(_coerceMap)
          .toList(growable: false);
    }
    if (value is Map) {
      // A to-many relation with exactly one row can arrive unwrapped.
      return <Map<String, Object?>>[_coerceMap(value)];
    }
    if (value is String && value.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .whereType<Map<Object?, Object?>>()
              .map(_coerceMap)
              .toList(growable: false);
        }
      } on FormatException {
        return const <Map<String, Object?>>[];
      }
    }
    return const <Map<String, Object?>>[];
  }

  /// Maps a nested array through [convert].
  List<T> list<T>(String key, T Function(Map<String, Object?> item) convert) =>
      objectList(key).map(convert).toList(growable: false);

  List<String> stringList(String key) {
    final Object? value = row[key];
    if (value == null) {
      return const <String>[];
    }
    if (value is List) {
      return value
          .where((Object? item) => item != null)
          .map((Object? item) => item.toString())
          .toList(growable: false);
    }
    if (value is String) {
      if (value.isEmpty) {
        return const <String>[];
      }
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((Object? item) => item.toString())
              .toList(growable: false);
        }
      } on FormatException {
        // A Postgres array literal `{a,b}` rather than JSON.
        if (value.startsWith('{') && value.endsWith('}')) {
          final String inner = value.substring(1, value.length - 1);
          if (inner.isEmpty) {
            return const <String>[];
          }
          return inner
              .split(',')
              .map((String item) => item.replaceAll('"', '').trim())
              .toList(growable: false);
        }
      }
      return <String>[value];
    }
    return const <String>[];
  }

  /// A `jsonb` column as a typed map, defaulting to empty.
  Map<String, Object?> jsonObject(String key) =>
      objectOrNull(key) ?? const <String, Object?>{};

  static Map<String, Object?> _coerceMap(Map<Object?, Object?> raw) {
    final Map<String, Object?> result = <String, Object?>{};
    raw.forEach((Object? key, Object? value) {
      result[key.toString()] = value;
    });
    return result;
  }
}

/// Shared behaviour for every persisted entity.
///
/// Implemented rather than extended so a model can still be a plain immutable
/// class with a const constructor.
abstract interface class SyncableModel {
  /// Primary key.
  String get id;

  /// Optimistic-concurrency counter, maintained by the `set_updated_at`
  /// trigger. The sync engine compares this against the server copy to detect
  /// a conflict instead of blindly overwriting.
  int get revision;

  DateTime? get updatedAt;

  /// Payload for an insert or update. Excludes server-managed columns.
  Map<String, Object?> toJson();

  /// Row shape for the local cache, which keeps every column.
  Map<String, Object?> toCacheJson();
}

/// Columns the server owns. A client must never send these, or it would
/// overwrite audit provenance with whatever it happened to be holding.
const Set<String> serverManagedColumns = <String>{
  'created_at',
  'updated_at',
  'created_by',
  'updated_by',
  'deleted_at',
  'deleted_by',
  'revision',
};

/// Strips server-managed keys and nulls from a write payload.
///
/// Removing nulls matters for a PATCH: sending `{"email": null}` clears the
/// column, whereas omitting the key leaves it untouched. Callers that
/// genuinely need to null a column pass it in [explicitNulls].
Map<String, Object?> buildWritePayload(
  Map<String, Object?> source, {
  Set<String> explicitNulls = const <String>{},
}) {
  final Map<String, Object?> payload = <String, Object?>{};
  source.forEach((String key, Object? value) {
    if (serverManagedColumns.contains(key)) {
      return;
    }
    if (value == null && !explicitNulls.contains(key)) {
      return;
    }
    payload[key] = value;
  });
  return payload;
}
