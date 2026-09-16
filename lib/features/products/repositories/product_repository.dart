import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/repositories/supabase_repository.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';

/// Remote data source for `products`, its colours and its images.
///
/// Shared across showrooms — see [ProductModel]. The colour helpers live here
/// rather than in their own repository because a colour has no meaning apart
/// from its product: it is never listed, searched or paginated on its own,
/// and giving it a separate [SupabaseRepository] would add a class whose only
/// purpose is to be reached through this one.
class ProductRepository extends SupabaseRepository<ProductModel> {
  ProductRepository({super.client});

  @override
  String get table => DbTables.products;

  @override
  String get defaultSortColumn => 'name';

  /// Embeds the brand name and the colour/image children in one round trip.
  ///
  /// Fetching them separately would mean three requests per page and a
  /// visible pop-in as each resolved; PostgREST resolves the whole graph
  /// server-side in a single query instead.
  @override
  String get defaultSelect =>
      '*, brands(id, name), product_colors(*), product_images(*)';

  @override
  ProductModel fromJson(Map<String, Object?> json) =>
      ProductModel.fromJson(json);

  /// Active products for a picker (a sale line, an inventory intake).
  ///
  /// [vehiclesOnly] narrows to serialised categories, which is what an
  /// inventory intake wants: an accessory has no chassis number and cannot
  /// occupy a row in `inventory`.
  Future<List<ProductModel>> listSelectable({bool vehiclesOnly = false}) {
    final List<QueryFilter> filters = <QueryFilter>[
      QueryFilter.equals('status', RecordStatus.active.value),
      if (vehiclesOnly)
        QueryFilter.inList(
          'category',
          ProductCategory.values
              .where((ProductCategory c) => c.isSerialisedVehicle)
              .map((ProductCategory c) => c.value)
              .toList(growable: false),
        ),
    ];

    return listAll(
      QueryParams(
        pageSize: 200,
        filters: filters,
        sorts: <QuerySort>[
          const QuerySort(column: 'name', direction: SortDirection.ascending),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- colours

  Future<List<ProductColorModel>> listColors(String productId) async {
    try {
      final List<Map<String, Object?>> rows = await client
          .from(DbTables.productColors)
          .select()
          .eq('product_id', productId)
          .order('color_name');
      return rows.map(ProductColorModel.fromJson).toList(growable: false);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<ProductColorModel> addColor({
    required String productId,
    required String colorName,
    required String hexCode,
  }) async {
    try {
      final Map<String, Object?> row = await client
          .from(DbTables.productColors)
          .insert(<String, Object?>{
            'product_id': productId,
            'color_name': colorName.trim(),
            'hex_code': normaliseHex(hexCode),
          })
          .select()
          .single();
      return ProductColorModel.fromJson(row);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Expands `#ABC` to `#AABBCC` and upper-cases the result.
  ///
  /// `AppValidators.hexColor` accepts the three-digit CSS shorthand, but
  /// `product_colors_hex_check` only accepts six digits. Without this, a
  /// perfectly reasonable `#ABC` passes client validation and then fails on
  /// the server with a constraint error the user cannot act on.
  static String normaliseHex(String value) {
    final String cleaned = value.trim().replaceFirst('#', '').toUpperCase();
    if (cleaned.length == 3) {
      final StringBuffer expanded = StringBuffer('#');
      for (final String digit in cleaned.split('')) {
        expanded.write(digit * 2);
      }
      return expanded.toString();
    }
    return '#$cleaned';
  }

  /// Retires or restores a colour.
  ///
  /// Deliberately not a delete. Units in stock and historical sales point at
  /// this row; removing it would either fail on the foreign key or orphan
  /// records that must stay readable for years.
  Future<ProductColorModel> setColorActive({
    required String colorId,
    required bool isActive,
  }) async {
    try {
      final Map<String, Object?> row = await client
          .from(DbTables.productColors)
          .update(<String, Object?>{'is_active': isActive})
          .eq('id', colorId)
          .select()
          .single();
      return ProductColorModel.fromJson(row);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}
