import 'dart:io';

import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the contract between the client's permission catalogue and the one
/// seeded into PostgreSQL by `supabase/migrations/008_roles_permissions.sql`.
///
/// The two must hold exactly the same `module.action` keys. If they drift, the
/// client either hides a button the user is entitled to press, or shows one
/// whose request the database will reject — both confusing, and neither
/// visible at compile time.
///
/// This test parses the migration directly rather than asserting a hardcoded
/// count, so adding a permission to only one side fails here.
void main() {
  group('AppPermissions catalogue integrity', () {
    test('every key is well-formed module.action', () {
      for (final String permission in AppPermissions.all) {
        expect(
          permission,
          matches(RegExp(r'^[a-z_]+\.[a-z_]+$')),
          reason: '"$permission" is not a valid module.action key',
        );

        final ({String module, String action}) parts = AppPermissions.parse(
          permission,
        );
        expect(parts.module, isNotEmpty);
        expect(parts.action, isNotEmpty);
      }
    });

    test('contains no duplicates', () {
      final Set<String> seen = <String>{};
      final List<String> duplicates = <String>[];
      for (final String permission in AppPermissions.all) {
        if (!seen.add(permission)) {
          duplicates.add(permission);
        }
      }
      expect(duplicates, isEmpty, reason: 'Duplicated: $duplicates');
    });

    test('every module referenced is declared in AppModule', () {
      final Set<String> declared = AppModule.all.toSet();
      final Set<String> used = AppPermissions.all
          .map((String p) => AppPermissions.parse(p).module)
          .toSet();

      expect(
        used.difference(declared),
        isEmpty,
        reason: 'Permissions reference modules missing from AppModule.all',
      );
      expect(
        declared.difference(used),
        isEmpty,
        reason: 'AppModule declares modules with no permissions',
      );
    });

    test('every module has at least a view permission', () {
      // A module without `view` is unreachable: the route guard would reject
      // every navigation to it.
      for (final String module in AppModule.all) {
        expect(
          AppPermissions.all.contains('$module.view'),
          isTrue,
          reason: 'Module "$module" has no view permission',
        );
      }
    });

    test('parse rejects malformed keys', () {
      expect(() => AppPermissions.parse('nodot'), throwsArgumentError);
      expect(() => AppPermissions.parse('.leading'), throwsArgumentError);
      expect(() => AppPermissions.parse('trailing.'), throwsArgumentError);
    });
  });

  group('Client catalogue matches the SQL seed', () {
    /// Extracts the `(module, action, description)` triples from the VALUES
    /// list in the permissions seed.
    Set<String> parseSeedPermissions(String sql) {
      // Narrow to the permissions INSERT so the role-grant VALUES list below
      // it is not picked up.
      final int start = sql.indexOf('insert into public.permissions');
      expect(
        start,
        greaterThan(-1),
        reason: 'Could not locate the permissions insert in the migration',
      );

      final int end = sql.indexOf('on conflict (module, action)', start);
      expect(
        end,
        greaterThan(start),
        reason: 'Could not locate the end of the permissions insert',
      );

      final String block = sql.substring(start, end);

      // Matches lines of the form:  ('module', 'action', 'description'),
      final RegExp entry = RegExp(
        r"\(\s*'([a-z_]+)'\s*,\s*'([a-z_]+)'\s*,",
        multiLine: true,
      );

      return entry
          .allMatches(block)
          .map((RegExpMatch m) => '${m.group(1)}.${m.group(2)}')
          .toSet();
    }

    test('the two catalogues are identical', () {
      final File migration = File(
        'supabase/migrations/008_roles_permissions.sql',
      );

      // Skip rather than fail when run from a directory where the migration is
      // not reachable; the assertion is meaningless without the file.
      if (!migration.existsSync()) {
        markTestSkipped(
          'Migration not found at ${migration.path}; run from the project root',
        );
        return;
      }

      final Set<String> fromSql = parseSeedPermissions(
        migration.readAsStringSync(),
      );
      final Set<String> fromDart = AppPermissions.all.toSet();

      expect(
        fromSql,
        isNotEmpty,
        reason: 'Parsed no permissions out of the migration',
      );

      final Set<String> missingInSql = fromDart.difference(fromSql);
      final Set<String> missingInDart = fromSql.difference(fromDart);

      expect(
        missingInSql,
        isEmpty,
        reason:
            'Declared in Dart but not seeded in SQL: '
            '${(missingInSql.toList()..sort()).join(', ')}',
      );

      expect(
        missingInDart,
        isEmpty,
        reason:
            'Seeded in SQL but not declared in Dart: '
            '${(missingInDart.toList()..sort()).join(', ')}',
      );

      expect(fromSql.length, fromDart.length);
    });
  });
}
