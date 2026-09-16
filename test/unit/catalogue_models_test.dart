import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/inventory/models/stock_movement_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/products/repositories/product_repository.dart';
import 'package:bike_showroom_management_system/features/vehicles/models/customer_vehicle_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductModel', () {
    test('reads an embedded brand, colours and images in one pass', () {
      final ProductModel product = ProductModel.fromJson(<String, Object?>{
        'id': 'p1',
        'name': 'Shine 125',
        'variant': 'Drum',
        'category': 'MOTORCYCLE',
        'engine_cc': 124,
        'fuel_type': 'PETROL',
        'transmission': 'MANUAL',
        'selling_price': 89500,
        'brands': <String, Object?>{'id': 'b1', 'name': 'Honda'},
        'product_colors': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'c1',
            'product_id': 'p1',
            'color_name': 'Pearl White',
            'hex_code': '#FFFFFF',
            'is_active': true,
          },
          <String, Object?>{
            'id': 'c2',
            'product_id': 'p1',
            'color_name': 'Retired Red',
            'hex_code': '#FF0000',
            'is_active': false,
          },
        ],
        'product_images': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'i1',
            'product_id': 'p1',
            'image_url': 'https://example.test/a.jpg',
            'sort_order': 2,
          },
          <String, Object?>{
            'id': 'i2',
            'product_id': 'p1',
            'image_url': 'https://example.test/b.jpg',
            'is_primary': true,
            'sort_order': 5,
          },
        ],
      });

      expect(product.brandName, 'Honda');
      expect(product.displayName, 'Honda Shine 125 Drum');
      expect(product.colors, hasLength(2));
      // A retired colour stays readable for the units that reference it but
      // must not be offered on a new intake.
      expect(product.activeColors.map((ProductColorModel c) => c.id), <String>[
        'c1',
      ]);
      // The flagged primary wins over the lowest sort order.
      expect(product.primaryImage!.id, 'i2');
    });

    test('falls back to the lowest sort order when none is primary', () {
      final ProductModel product = ProductModel.fromJson(<String, Object?>{
        'id': 'p1',
        'name': 'Activa',
        'product_images': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'i1',
            'product_id': 'p1',
            'image_url': 'a',
            'sort_order': 7,
          },
          <String, Object?>{
            'id': 'i2',
            'product_id': 'p1',
            'image_url': 'b',
            'sort_order': 3,
          },
        ],
      });

      expect(product.primaryImage!.id, 'i2');
    });

    test('omits displacement and gearbox for a non-vehicle product', () {
      final ProductModel helmet = ProductModel.fromJson(<String, Object?>{
        'id': 'p2',
        'name': 'Helmet',
        'category': 'ACCESSORY',
        'fuel_type': 'PETROL',
      });

      expect(helmet.isSerialisedVehicle, isFalse);
      // "0 cc" and a transmission on a helmet would be printed on quotations.
      expect(helmet.specSummary, 'Petrol');
    });

    test('write payload drops server-managed columns', () {
      final ProductModel product = ProductModel.fromJson(<String, Object?>{
        'id': 'p1',
        'name': 'Shine',
        'revision': 4,
        'created_at': '2026-01-01T00:00:00Z',
        'created_by': 'someone',
      });

      final Map<String, Object?> payload = product.toJson();
      expect(payload.containsKey('revision'), isFalse);
      expect(payload.containsKey('created_at'), isFalse);
      expect(payload.containsKey('created_by'), isFalse);
      expect(payload['name'], 'Shine');
    });
  });

  group('ProductColorModel', () {
    test('parses a hex code into an opaque colour', () {
      const ProductColorModel color = ProductColorModel(
        id: 'c1',
        productId: 'p1',
        colorName: 'Blue',
        hexCode: '#1A73E8',
      );
      expect(color.swatch.toARGB32(), 0xFF1A73E8);
    });

    test('falls back rather than throwing on a malformed hex code', () {
      // A row can arrive from an older local cache that predates the
      // constraint, and a crash in a list cell is worse than a grey dot.
      const ProductColorModel color = ProductColorModel(
        id: 'c1',
        productId: 'p1',
        colorName: 'Broken',
        hexCode: 'not-a-colour',
      );
      expect(color.swatch.toARGB32(), 0xFF9E9E9E);
    });
  });

  group('ProductRepository.normaliseHex', () {
    test('expands the three-digit shorthand the database rejects', () {
      // AppValidators.hexColor accepts #ABC, but product_colors_hex_check
      // only accepts six digits.
      expect(ProductRepository.normaliseHex('#abc'), '#AABBCC');
    });

    test('upper-cases and adds a missing hash', () {
      expect(ProductRepository.normaliseHex('1a73e8'), '#1A73E8');
    });
  });

  group('InventoryModel', () {
    Map<String, Object?> row({String status = 'AVAILABLE'}) =>
        <String, Object?>{
          'id': 'u1',
          'showroom_id': 's1',
          'product_id': 'p1',
          'stock_code': 'SMI/STK/2627/0001',
          'chassis_number': 'ME4JC36CKNT000123',
          'engine_number': 'JC36ET0000123',
          'purchase_price': 78000,
          'purchase_date': '2026-06-15',
          'status': status,
          'products': <String, Object?>{
            'id': 'p1',
            'name': 'Shine 125',
            'brands': <String, Object?>{'id': 'b1', 'name': 'Honda'},
          },
          'product_colors': <String, Object?>{
            'id': 'c1',
            'color_name': 'Pearl White',
            'hex_code': '#FFFFFF',
          },
        };

    test('builds a display name from the embedded product and colour', () {
      expect(
        InventoryModel.fromJson(row()).displayName,
        'Honda Shine 125 - Pearl White',
      );
    });

    test('ages from the purchase date', () {
      final DateTime purchased = DateTime.now().subtract(
        const Duration(days: 45),
      );
      final InventoryModel unit = InventoryModel.fromJson(<String, Object?>{
        ...row(),
        'purchase_date':
            '${purchased.year}-'
            '${purchased.month.toString().padLeft(2, '0')}-'
            '${purchased.day.toString().padLeft(2, '0')}',
      });
      expect(unit.ageInDays, 45);
    });

    test('only allocatable statuses may be attached to a sale', () {
      expect(InventoryModel.fromJson(row()).isAllocatable, isTrue);
      expect(
        InventoryModel.fromJson(row(status: 'DAMAGED')).isAllocatable,
        isFalse,
      );
      expect(InventoryModel.fromJson(row(status: 'SOLD')).isSold, isTrue);
    });

    test('sends dates as ISO, not the display format', () {
      // A `date` column rejects `15/06/2026`; the display formatter would
      // have produced exactly that.
      final Map<String, Object?> payload = InventoryModel.fromJson(
        row(),
      ).toJson();
      expect(payload['purchase_date'], '2026-06-15');
    });

    test('upper-cases the identifiers before they leave the client', () {
      const InventoryModel unit = InventoryModel(
        id: 'u1',
        showroomId: 's1',
        productId: 'p1',
        stockCode: 'STK1',
        chassisNumber: ' me4jc36cknt000123 ',
        engineNumber: 'jc36et0000123',
      );
      final Map<String, Object?> payload = unit.toJson();
      expect(payload['chassis_number'], 'ME4JC36CKNT000123');
      expect(payload['engine_number'], 'JC36ET0000123');
    });
  });

  group('StockMovementModel', () {
    test('leaves a missing from-status null rather than defaulting it', () {
      // `InventoryStatus.fromValue` falls back to `available`, which would
      // turn a unit's first movement into a fabricated
      // "Available -> Available".
      final StockMovementModel movement =
          StockMovementModel.fromJson(<String, Object?>{
            'id': 'm1',
            'showroom_id': 's1',
            'inventory_id': 'u1',
            'movement_type': 'STOCK_IN',
            'to_status': 'AVAILABLE',
          });

      expect(movement.fromStatus, isNull);
      expect(movement.transition, 'Available');
    });

    test('renders a transition between two statuses', () {
      final StockMovementModel movement = StockMovementModel.fromJson(
        <String, Object?>{
          'id': 'm2',
          'showroom_id': 's1',
          'inventory_id': 'u1',
          'movement_type': 'RESERVATION',
          'from_status': 'AVAILABLE',
          'to_status': 'RESERVED',
          'inventory': <String, Object?>{'stock_code': 'STK1'},
          'users': <String, Object?>{'name': 'Asha'},
        },
      );

      expect(movement.transition, 'Available -> Reserved');
      expect(movement.stockCode, 'STK1');
      expect(movement.createdByName, 'Asha');
    });
  });

  group('CustomerModel', () {
    test('reads the aggregate vehicle count PostgREST returns', () {
      final CustomerModel customer = CustomerModel.fromJson(<String, Object?>{
        'id': 'c1',
        'showroom_id': 's1',
        'customer_code': 'SMI/CUS/2627/0001',
        'name': 'Ramesh Verma',
        'phone': '9876543210',
        'customer_type': 'INDIVIDUAL',
        'customer_vehicles': <Map<String, Object?>>[
          <String, Object?>{'count': 3},
        ],
      });

      expect(customer.vehicleCount, 3);
      expect(customer.requiresGst, isFalse);
    });

    test('defaults the count to zero when the embed was not requested', () {
      final CustomerModel customer = CustomerModel.fromJson(<String, Object?>{
        'id': 'c1',
        'showroom_id': 's1',
        'customer_code': 'X',
        'name': 'A',
        'phone': '9876543210',
      });
      expect(customer.vehicleCount, 0);
    });

    test('a corporate buyer needs a GST number', () {
      final CustomerModel corporate = CustomerModel.fromJson(<String, Object?>{
        'id': 'c2',
        'showroom_id': 's1',
        'customer_code': 'X',
        'name': 'Acme Logistics',
        'phone': '9876543211',
        'customer_type': 'CORPORATE',
      });
      expect(corporate.requiresGst, isTrue);
    });
  });

  group('CustomerVehicleModel', () {
    Map<String, Object?> row({
      String? registration,
      String? insuranceEnd,
    }) => <String, Object?>{
      'id': 'v1',
      'showroom_id': 's1',
      'customer_id': 'c1',
      'product_id': 'p1',
      'chassis_number': 'ME4JC36CKNT000123',
      'engine_number': 'JC36ET0000123',
      'registration_number': registration,
      'insurance_end': insuranceEnd,
      'current_odometer': 12500,
      'customers': <String, Object?>{'name': 'Ramesh', 'phone': '9876543210'},
      'products': <String, Object?>{
        'name': 'Shine 125',
        'brands': <String, Object?>{'name': 'Honda'},
      },
    };

    test('identifies an unregistered vehicle by its chassis number', () {
      // A newly delivered bike has no plate for several weeks.
      expect(
        CustomerVehicleModel.fromJson(row()).displayIdentifier,
        'ME4JC36CKNT000123',
      );
      expect(
        CustomerVehicleModel.fromJson(
          row(registration: 'MP09AB1234'),
        ).displayIdentifier,
        'MP09AB1234',
      );
    });

    test('flags a lapsed policy and one about to lapse', () {
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final CustomerVehicleModel lapsed = CustomerVehicleModel.fromJson(
        row(
          insuranceEnd: iso(DateTime.now().subtract(const Duration(days: 5))),
        ),
      );
      final CustomerVehicleModel soon = CustomerVehicleModel.fromJson(
        row(insuranceEnd: iso(DateTime.now().add(const Duration(days: 10)))),
      );
      final CustomerVehicleModel comfortable = CustomerVehicleModel.fromJson(
        row(insuranceEnd: iso(DateTime.now().add(const Duration(days: 300)))),
      );

      expect(lapsed.isInsuranceActive, isFalse);
      expect(soon.isInsuranceActive, isTrue);
      expect(soon.isInsuranceExpiringSoon, isTrue);
      expect(comfortable.isInsuranceExpiringSoon, isFalse);
    });

    test('a scrapped vehicle is not serviceable', () {
      final CustomerVehicleModel scrapped = CustomerVehicleModel.fromJson(
        <String, Object?>{...row(), 'status': 'SCRAPPED'},
      );
      expect(scrapped.isServiceable, isFalse);
      expect(CustomerVehicleModel.fromJson(row()).isServiceable, isTrue);
    });

    test('sends every date as ISO', () {
      final CustomerVehicleModel vehicle =
          CustomerVehicleModel.fromJson(<String, Object?>{
            ...row(registration: 'MP09AB1234'),
            'registration_date': '2026-07-01',
            'warranty_end': '2028-07-01',
          });
      final Map<String, Object?> payload = vehicle.toJson();
      expect(payload['registration_date'], '2026-07-01');
      expect(payload['warranty_end'], '2028-07-01');
      expect(payload['registration_number'], 'MP09AB1234');
    });
  });
}
