// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/customers/repositories/customer_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/models/stock_movement_model.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/inventory_repository.dart';
import 'package:bike_showroom_management_system/features/inventory/repositories/stock_movement_repository.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/brand_repository.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:bike_showroom_management_system/features/vehicles/repositories/customer_vehicle_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart' as supabase;

/// Exercises the Phase 4 feature repositories against a **real** PostgREST
/// instance.
///
/// `supabase_repository_integration_test.dart` proves the generic base class
/// builds valid queries. This file proves the things only these repositories
/// have: the multi-level PostgREST **embeds** each `defaultSelect` declares
/// (`products(..., brands(...))`, the `customer_vehicles(count)` aggregate),
/// the two RPCs stock intake depends on, and that each model parses the exact
/// JSON shape PostgREST returns for them. Every one of those is a string that
/// the Dart compiler cannot check and a unit test with a hand-written fixture
/// cannot falsify — a mistyped relation name looks perfectly fine right up to
/// the moment a real server answers with an error.
///
/// Skipped unless a live server is described in the environment; see
/// `supabase/tests/README.md` and the sibling integration test's header.
void main() {
  final String? baseUrl = Platform.environment['SUPABASE_TEST_URL'];
  final String? jwtSecret = Platform.environment['SUPABASE_TEST_JWT_SECRET'];
  final String? sub = Platform.environment['SUPABASE_TEST_SUB'];
  final String? showroomId = Platform.environment['SUPABASE_TEST_SHOWROOM_ID'];

  final bool isConfigured =
      baseUrl != null && jwtSecret != null && sub != null && showroomId != null;

  group('Catalogue repositories against a live PostgREST instance', () {
    if (!isConfigured) {
      test(
        'SKIPPED - set SUPABASE_TEST_URL / _JWT_SECRET / _SUB / _SHOWROOM_ID '
        'to run this against a live server',
        () {},
        skip: 'No live server configured; see the file header.',
      );
      return;
    }

    late supabase.SupabaseClient client;
    late BrandRepository brands;
    late ProductRepository products;
    late InventoryRepository inventory;
    late StockMovementRepository movements;
    late CustomerRepository customers;
    late CustomerVehicleRepository vehicles;

    // A per-run suffix keeps re-runs from colliding on the unique indexes over
    // chassis number, phone and product name.
    final String tag = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(6);

    String? productId;
    String? colorId;
    String? unitId;
    String? customerId;
    String? vehicleId;

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
        accessToken: () async => userJwt,
      );

      brands = BrandRepository(client: client);
      products = ProductRepository(client: client);
      inventory = InventoryRepository(client: client);
      movements = StockMovementRepository(client: client);
      customers = CustomerRepository(client: client);
      vehicles = CustomerVehicleRepository(client: client);
    });

    tearDownAll(() async {
      // Reverse dependency order, best effort: a failed test earlier leaves
      // some of these null, and a re-run must still start clean.
      Future<void> remove(String table, String? id) async {
        if (id == null) {
          return;
        }
        try {
          await client.from(table).delete().eq('id', id);
        } on Object {
          // Already gone, or held by a row this cleanup could not remove.
        }
      }

      await remove('customer_vehicles', vehicleId);
      await remove('inventory', unitId);
      await remove('customers', customerId);
      await remove('product_colors', colorId);
      await remove('products', productId);
    });

    test('a product round-trips with its brand, colours and images', () async {
      final List<dynamic> brandRows = await client
          .from('brands')
          .select('id')
          .limit(1);
      expect(
        brandRows,
        isNotEmpty,
        reason: '014_seed_data.sql should have seeded brands',
      );
      final String brandId =
          (brandRows.first as Map<String, dynamic>)['id']! as String;

      final ProductModel created = await products.create(<String, Object?>{
        'brand_id': brandId,
        'name': 'IntegrationTest $tag',
        'variant': 'Drum',
        'category': 'MOTORCYCLE',
        'engine_cc': 124,
        'fuel_type': 'PETROL',
        'transmission': 'MANUAL',
        'base_price': 75000,
        'selling_price': 89500,
        'tax_rate': 28,
        'warranty_months': 24,
      });
      productId = created.id;

      // The embed is the point: `brands(id, name)` has to resolve through the
      // brand_id foreign key and land in the model's `brandName`.
      expect(created.brandName, isNotNull);
      expect(created.displayName, contains('IntegrationTest $tag'));
      expect(created.colors, isEmpty);

      final ProductModel fetched = await products.getById(created.id);
      expect(fetched.brandName, created.brandName);
    });

    test('addColor expands the shorthand hex the database rejects', () async {
      // `product_colors_hex_check` only accepts six digits, while
      // AppValidators.hexColor accepts the three-digit CSS shorthand. If the
      // repository did not expand it, this insert would fail outright.
      final ProductColorModel color = await products.addColor(
        productId: productId!,
        colorName: 'Test White $tag',
        hexCode: '#fff',
      );
      colorId = color.id;

      expect(color.hexCode, '#FFFFFF');
      expect(color.isActive, isTrue);
    });

    test('retiring a colour hides it from pickers but keeps the row', () async {
      final ProductColorModel retired = await products.setColorActive(
        colorId: colorId!,
        isActive: false,
      );
      expect(retired.isActive, isFalse);

      final ProductModel reloaded = await products.getById(productId!);
      expect(
        reloaded.colors.map((ProductColorModel c) => c.id),
        contains(colorId),
      );
      // Still readable for units that reference it, but never offered again.
      expect(reloaded.activeColors, isEmpty);

      await products.setColorActive(colorId: colorId!, isActive: true);
    });

    test(
      'listSelectable(vehiclesOnly) excludes non-vehicle categories',
      () async {
        final List<ProductModel> selectable = await products.listSelectable(
          vehiclesOnly: true,
        );
        expect(selectable, isNotEmpty);
        expect(
          selectable.every((ProductModel p) => p.category.isSerialisedVehicle),
          isTrue,
        );
      },
    );

    test('a stock code is allocated and a unit takes it', () async {
      final String stockCode = await inventory.nextStockCode(showroomId);
      expect(stockCode, isNotEmpty);

      // Chassis format: `^[A-HJ-NPR-Z0-9]{11,25}$` - no I, O or Q, which is
      // why the tag is digits only.
      final InventoryModel unit = await inventory.create(<String, Object?>{
        'showroom_id': showroomId,
        'product_id': productId,
        'color_id': colorId,
        'stock_code': stockCode,
        'chassis_number': 'ZZTEST$tag',
        'engine_number': 'ZZENG$tag',
        'purchase_date': '2026-06-15',
        'purchase_price': 78000,
        'status': 'AVAILABLE',
      });
      unitId = unit.id;

      expect(unit.stockCode, stockCode);
      // Two levels of embed on one row: product, and the brand under it.
      expect(unit.productName, contains('IntegrationTest'));
      expect(unit.brandName, isNotNull);
      expect(unit.colorName, 'Test White $tag');
      expect(unit.status, InventoryStatus.available);
    });

    test('the intake is already in the movement history', () async {
      final PaginatedResponse<StockMovementModel> page = await movements.list(
        QueryParams(
          pageSize: 10,
          filters: <QueryFilter>[QueryFilter.equals('inventory_id', unitId)],
        ),
      );

      expect(page.items, hasLength(1));
      final StockMovementModel first = page.items.single;
      expect(first.movementType, StockMovementType.stockIn);
      expect(first.toStatus, InventoryStatus.available);
      // The trigger writes NULL here on a unit's first movement. Parsing it
      // through `InventoryStatus.fromValue` would silently render
      // "Available -> Available".
      expect(first.fromStatus, isNull);
      expect(first.transition, 'Available');
      expect(first.stockCode, isNotNull);
      expect(first.createdByName, isNotNull);
    });

    test('adjust_inventory moves the unit and records the movement', () async {
      await inventory.adjustStatus(
        inventoryId: unitId!,
        newStatus: InventoryStatus.reserved,
        reason: 'Held for an integration test',
      );

      final InventoryModel reloaded = await inventory.getById(unitId!);
      expect(reloaded.status, InventoryStatus.reserved);
      // The reason lands on the unit's own notes, not on the movement row.
      expect(reloaded.notes, 'Held for an integration test');

      final PaginatedResponse<StockMovementModel> page = await movements.list(
        QueryParams(
          pageSize: 10,
          filters: <QueryFilter>[QueryFilter.equals('inventory_id', unitId)],
          sorts: <QuerySort>[const QuerySort(column: 'created_at')],
        ),
      );
      expect(page.items.first.fromStatus, InventoryStatus.available);
      expect(page.items.first.toStatus, InventoryStatus.reserved);
    });

    test('statusCounts reports one reserved unit', () async {
      final Map<InventoryStatus, int> counts = await inventory.statusCounts(
        showroomId,
      );
      expect(counts[InventoryStatus.reserved], greaterThanOrEqualTo(1));
    });

    test('a customer carries an aggregate vehicle count', () async {
      final String code = await customers.nextCustomerCode(showroomId);
      final CustomerModel created = await customers.create(<String, Object?>{
        'showroom_id': showroomId,
        'customer_code': code,
        'name': 'Integration Customer $tag',
        // Ten digits starting 6-9, per `customers_phone_check`.
        'phone': '9${tag.padLeft(9, '0').substring(0, 9)}',
        'customer_type': 'INDIVIDUAL',
      });
      customerId = created.id;

      expect(created.customerCode, code);
      // No vehicles yet; the embed must yield 0 rather than throwing on an
      // empty aggregate array.
      expect(created.vehicleCount, 0);
    });

    test('findByPhone locates the customer just created', () async {
      final CustomerModel created = await customers.getById(customerId!);
      final CustomerModel? found = await customers.findByPhone(
        showroomId: showroomId,
        phone: created.phone,
      );
      expect(found, isNotNull);
      expect(found!.id, customerId);
    });

    test('a vehicle embeds its owner and its model', () async {
      final CustomerVehicleModel created = await vehicles
          .create(<String, Object?>{
            'showroom_id': showroomId,
            'customer_id': customerId,
            'product_id': productId,
            'inventory_id': unitId,
            'chassis_number': 'ZZTEST$tag',
            'engine_number': 'ZZENG$tag',
            'current_odometer': 150,
            'warranty_start': '2026-09-01',
            'warranty_end': '2028-09-01',
          });
      vehicleId = created.id;

      expect(created.customerName, contains('Integration Customer'));
      expect(created.brandName, isNotNull);
      expect(created.productName, contains('IntegrationTest'));
      expect(created.displayIdentifier, 'ZZTEST$tag');
    });

    test('the vehicle now shows in the owner\'s aggregate count', () async {
      final CustomerModel reloaded = await customers.getById(customerId!);
      expect(reloaded.vehicleCount, 1);
    });

    test('listForCustomer returns only that customer\'s vehicles', () async {
      final List<CustomerVehicleModel> owned = await vehicles.listForCustomer(
        customerId!,
      );
      expect(owned, hasLength(1));
      expect(owned.single.id, vehicleId);
    });

    test('brands are visible without a showroom scope', () async {
      // The catalogue is shared: scoping it by showroom would hide every
      // manufacturer, since `brands` has no showroom_id at all.
      final List<dynamic> active = await brands.listActive();
      expect(active, isNotEmpty);
    });
  });
}

/// HS256 JWT, standing in for GoTrue. See the sibling integration test.
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
