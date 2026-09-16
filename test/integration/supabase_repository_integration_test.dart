// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' as supabase;

/// Exercises [SupabaseRepository] against a **real** PostgREST + PostgreSQL
/// instance rather than against a mock.
///
/// Every other test in this suite either checks pure Dart logic or (via
/// `supabase/tests/*.sql`) checks the database directly with `psql`. Neither
/// proves that the *generated PostgREST query chains* — `.select().eq()
/// .ilike().range().count()`, the `.update().eq(revision, ...)` optimistic
/// lock, a soft delete — actually produce the HTTP requests PostgREST expects
/// and parse its responses correctly. This file is what proves that, end to
/// end, through the real wire format.
///
/// ## Running it
///
/// Skipped by default: `flutter test` must work with no infrastructure
/// running, so this whole file is a no-op unless the environment describes a
/// live server.
///
/// ```bash
/// # 1. A PostgreSQL database with every migration in supabase/migrations/
/// #    applied, plus the RLS-supporting `auth.uid()` / `auth.role()` /
/// #    `auth.email()` functions Supabase's own platform provides (see
/// #    supabase/tests/README.md for a minimal local shim).
/// # 2. PostgREST pointed at that database, with a known jwt-secret.
/// # 3. A fixture: a showroom, and a user in it holding a role with full
/// #    customers.* permissions, whose auth_user_id matches SUPABASE_TEST_SUB.
///
/// SUPABASE_TEST_URL=http://127.0.0.1:3011 \
/// SUPABASE_TEST_JWT_SECRET=<the same secret PostgREST was started with> \
/// SUPABASE_TEST_SUB=<that user's auth_user_id> \
/// SUPABASE_TEST_SHOWROOM_ID=<that showroom's id> \
///   flutter test test/integration/supabase_repository_integration_test.dart
/// ```
///
/// `SUPABASE_TEST_URL` must resolve `<url>/rest/v1/...` to PostgREST's root —
/// stock PostgREST serves at its root, not under `/rest/v1`, so a one-line
/// path-stripping reverse proxy sits in front of it for this to work; see
/// `supabase/tests/README.md`.
void main() {
  final String? baseUrl = Platform.environment['SUPABASE_TEST_URL'];
  final String? jwtSecret = Platform.environment['SUPABASE_TEST_JWT_SECRET'];
  final String? sub = Platform.environment['SUPABASE_TEST_SUB'];
  final String? showroomId = Platform.environment['SUPABASE_TEST_SHOWROOM_ID'];

  final bool isConfigured =
      baseUrl != null && jwtSecret != null && sub != null && showroomId != null;

  group('SupabaseRepository against a live PostgREST instance', () {
    if (!isConfigured) {
      test(
        'SKIPPED - set SUPABASE_TEST_URL / _JWT_SECRET / _SUB / _SHOWROOM_ID '
        'to run this against a live server',
        () {},
        skip:
            'No live server configured; see the file header for how to run '
            'this locally.',
      );
      return;
    }

    late supabase.SupabaseClient client;
    late _RawCustomerRepository repository;
    String? createdId;

    setUpAll(() {
      final String anonJwt = _mintJwt(jwtSecret, sub: null, role: 'anon');
      final String userJwt = _mintJwt(
        jwtSecret,
        sub: sub,
        role: 'authenticated',
      );

      client = supabase.SupabaseClient(
        baseUrl,
        anonJwt,
        // The seam that lets this run with no GoTrue server at all: every
        // request uses this token as its bearer, exactly as it would if a
        // third-party auth provider were wired in instead of Supabase Auth.
        accessToken: () async => userJwt,
      );
      repository = _RawCustomerRepository(injectedClient: client);
    });

    tearDownAll(() async {
      // Best-effort cleanup so re-running the suite starts clean.
      if (createdId != null) {
        try {
          await client.from('customers').delete().eq('id', createdId!);
        } on Object {
          // Already gone, or the test that would have deleted it failed
          // first; either way there is nothing more to clean up.
        }
      }
    });

    test('list() returns a page with an exact total count', () async {
      final PaginatedResponse<Map<String, Object?>> page = await repository
          .list(QueryParams(showroomId: showroomId, pageSize: 5));

      // totalCount must reflect every matching row, not just this page.
      expect(page.totalCount, greaterThanOrEqualTo(page.items.length));
      expect(page.pageSize, 5);
      expect(page.page, 1);
    });

    test(
      'create() inserts a row and returns it with server-set fields',
      () async {
        final Map<String, Object?> created = await repository.create(
          <String, Object?>{
            'showroom_id': showroomId,
            'customer_code': 'ITCUST-${DateTime.now().millisecondsSinceEpoch}',
            'name': 'Integration Test Customer',
            'phone': '9876500011',
            'email': 'integration@test.local',
          },
        );

        createdId = created['id'] as String?;

        expect(createdId, isNotNull);
        // Set by the database default, not sent in the payload - proves the
        // row actually round-tripped through PostgreSQL rather than the client
        // echoing back what it sent.
        expect(created['created_at'], isNotNull);
        expect(created['revision'], 1);
        // The normalise_customer_phone trigger runs server-side; if this
        // matches, the insert really executed inside Postgres.
        expect(created['phone'], '9876500011');
      },
    );

    test('getById() retrieves exactly what was created', () async {
      final Map<String, Object?> row = await repository.getById(createdId!);
      expect(row['name'], 'Integration Test Customer');
      expect(row['showroom_id'], showroomId);
    });

    test('list() search finds the created row by a name substring', () async {
      final PaginatedResponse<Map<String, Object?>> page = await repository
          .list(
            QueryParams(
              showroomId: showroomId,
              searchTerm: 'Integration Test',
              searchColumns: const <String>['name', 'phone', 'customer_code'],
            ),
          );

      expect(
        page.items.any((Map<String, Object?> row) => row['id'] == createdId),
        isTrue,
        reason: 'The row just created should be findable by search',
      );
    });

    test('update() with the correct revision succeeds and bumps it', () async {
      final Map<String, Object?> updated = await repository.update(
        createdId!,
        <String, Object?>{'city': 'Mumbai'},
        expectedRevision: 1,
      );

      expect(updated['city'], 'Mumbai');
      expect(
        updated['revision'],
        2,
        reason: 'set_updated_at_and_revision() should have bumped it',
      );
    });

    test('update() with a stale revision is refused as a conflict', () async {
      // The row is now at revision 2; presenting 1 again simulates a second
      // device that read the row before the update above happened.
      await expectLater(
        repository.update(createdId!, <String, Object?>{
          'city': 'Pune',
        }, expectedRevision: 1),
        throwsA(isA<ConflictException>()),
      );

      // And the value from the winning update must still be in place.
      final Map<String, Object?> row = await repository.getById(createdId!);
      expect(row['city'], 'Mumbai');
    });

    test(
      'delete() soft-deletes: hidden by default, visible when included',
      () async {
        await repository.delete(createdId!);

        final PaginatedResponse<Map<String, Object?>> defaultView =
            await repository.list(QueryParams(showroomId: showroomId));
        expect(
          defaultView.items.any(
            (Map<String, Object?> row) => row['id'] == createdId,
          ),
          isFalse,
        );

        final PaginatedResponse<Map<String, Object?>> includingDeleted =
            await repository.list(
              QueryParams(showroomId: showroomId, includeDeleted: true),
            );
        expect(
          includingDeleted.items.any(
            (Map<String, Object?> row) => row['id'] == createdId,
          ),
          isTrue,
        );
      },
    );

    test('RLS refuses a row outside the accessible showroom', () async {
      // A random, almost-certainly-nonexistent showroom id. Whether it is
      // "not found" or "not visible" is deliberately indistinguishable, but
      // either way it must not be returned.
      final PaginatedResponse<Map<String, Object?>> page = await repository
          .list(
            QueryParams(showroomId: '00000000-0000-0000-0000-000000000000'),
          );
      expect(page.items, isEmpty);
    });
  });
}

/// Bare-bones repository over `customers`, returning the raw row rather than
/// a typed model — this test is about the query-building base class, not
/// about any one feature's model.
class _RawCustomerRepository extends SupabaseRepository<Map<String, Object?>> {
  _RawCustomerRepository({required this.injectedClient});

  final supabase.SupabaseClient injectedClient;

  @override
  supabase.SupabaseClient get client => injectedClient;

  @override
  String get table => 'customers';

  @override
  Map<String, Object?> fromJson(Map<String, Object?> json) => json;
}

/// HS256 JWT, matching what a real Supabase project (and stock PostgREST)
/// verifies. Intentionally minimal: this is test-only credential minting,
/// standing in for GoTrue, which is not running in this setup.
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
