import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/config/supabase_config.dart';
import 'package:bike_showroom_management_system/core/constants/db_constants.dart';
import 'package:bike_showroom_management_system/core/errors/app_exception.dart';
import 'package:bike_showroom_management_system/core/errors/error_mapper.dart';
import 'package:bike_showroom_management_system/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base remote data source for a table, backed directly by the Supabase
/// client.
///
/// ## Where this sits in the architecture
///
/// `Controller -> Repository -> Service/API -> Supabase`. For a table reached
/// straight through PostgREST (the overwhelming majority of reads and simple
/// writes), this class **is** the remote service: subclassing it in a
/// feature's `repositories/` folder gives that feature typed CRUD with
/// pagination, search, filtering and sorting for free, while every
/// authorisation decision is still made by Row Level Security on the server —
/// this class does not, and must not, attempt to replicate that logic
/// client-side.
///
/// A feature repository composes this with a local cache and a sync queue
/// once those exist (Phase 10); until then, a subclass talks to Supabase
/// directly and that is the complete, correct behaviour for an online-first
/// screen.
///
/// ## What a subclass supplies
///
/// - [table]: the table name, from [DbTables].
/// - [fromJson]: builds the domain model from a row.
/// - [defaultSelect]: override to embed a relation (`*, brands(*)`).
/// - [softDeleteColumn]: override to `null` for a table with no `is_deleted`
///   column (most lookup/child tables), so soft-delete filtering is skipped.
abstract class SupabaseRepository<T> {
  SupabaseRepository({SupabaseClient? client}) : _injectedClient = client;

  final SupabaseClient? _injectedClient;

  SupabaseClient get client => _injectedClient ?? SupabaseConfig.client;

  /// The table this repository reads and writes.
  String get table;

  /// Parses one row into the domain model.
  T fromJson(Map<String, Object?> json);

  /// PostgREST select expression. Override to embed a relation, e.g.
  /// `'*, brands(name), product_colors(*)'`.
  String get defaultSelect => '*';

  /// Column used for soft-delete filtering, or null when [table] has none.
  String? get softDeleteColumn => DbColumns.isDeleted;

  /// Column the "most recent first" default sort uses when the caller has not
  /// requested a specific order.
  String get defaultSortColumn => DbColumns.createdAt;

  // -------------------------------------------------------------- reading

  /// Fetches one page matching [params].
  Future<PaginatedResponse<T>> list(
    QueryParams params, {
    String? select,
  }) async {
    try {
      PostgrestFilterBuilder<PostgrestList> query = client
          .from(table)
          .select(select ?? defaultSelect);

      query = _applyFilters(query, params);

      final PostgrestTransformBuilder<PostgrestList> ordered = _applySort(
        query,
        params,
      );

      final PostgrestResponse<PostgrestList> response = await ordered
          .range(params.offset, params.rangeEnd)
          .count(CountOption.exact);

      final List<T> items = response.data
          .map(
            (Object? row) => fromJson(Map<String, Object?>.from(row! as Map)),
          )
          .toList(growable: false);

      return PaginatedResponse<T>(
        items: items,
        totalCount: response.count,
        page: params.page,
        pageSize: params.pageSize,
        fetchedAt: DateTime.now(),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to list $table',
        tag: 'repository',
        error: error,
        stackTrace: stackTrace,
      );
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Fetches every row matching [params], ignoring pagination — for a
  /// dropdown source or an export. Bounded by [AppConstants.maxExportRows]
  /// semantics is the caller's responsibility; this issues one request per
  /// [batchSize] rows.
  Future<List<T>> listAll(
    QueryParams params, {
    String? select,
    int batchSize = 500,
    int maxRows = 20000,
  }) async {
    final List<T> all = <T>[];
    int page = 1;
    while (all.length < maxRows) {
      final PaginatedResponse<T> response = await list(
        params.copyWith(page: page, pageSize: batchSize),
        select: select,
      );
      all.addAll(response.items);
      if (!response.hasNextPage || response.isEmpty) {
        break;
      }
      page++;
    }
    return all;
  }

  /// Fetches a single row by primary key. Throws [NotFoundException] when
  /// absent or invisible under RLS — the two are indistinguishable by design.
  Future<T> getById(String id, {String? select}) async {
    try {
      final Map<String, Object?> row = await client
          .from(table)
          .select(select ?? defaultSelect)
          .eq(DbColumns.id, id)
          .single();
      return fromJson(row);
    } on PostgrestException catch (error, stackTrace) {
      throw ErrorMapper.mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Like [getById] but returns null instead of throwing when absent.
  Future<T?> getByIdOrNull(String id, {String? select}) async {
    try {
      final Map<String, Object?>? row = await client
          .from(table)
          .select(select ?? defaultSelect)
          .eq(DbColumns.id, id)
          .maybeSingle();
      return row == null ? null : fromJson(row);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  // -------------------------------------------------------------- writing

  /// Inserts a new row and returns the created model.
  Future<T> create(Map<String, Object?> payload) async {
    try {
      final Map<String, Object?> row = await client
          .from(table)
          .insert(payload)
          .select(defaultSelect)
          .single();
      return fromJson(row);
    } on PostgrestException catch (error, stackTrace) {
      throw ErrorMapper.mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Updates an existing row and returns the updated model.
  ///
  /// [expectedRevision] pins an optimistic-concurrency check: if supplied and
  /// the row's `revision` has moved since it was read, the update matches zero
  /// rows and a [ConflictException] is raised rather than silently
  /// overwriting a change the caller never saw.
  Future<T> update(
    String id,
    Map<String, Object?> payload, {
    int? expectedRevision,
  }) async {
    try {
      // Typed as `void` because that is what `PostgrestQueryBuilder<void>`
      // (the type of `client.from(table)`) propagates through `.update()`
      // and `.eq()`. The list-of-rows type only appears once `.select()` is
      // called below, which is why this intermediate is not typed as
      // `PostgrestFilterBuilder<PostgrestList>` — the row shape does not
      // exist yet at this point in the chain.
      PostgrestFilterBuilder<void> query = client
          .from(table)
          .update(payload)
          .eq(DbColumns.id, id);

      if (expectedRevision != null) {
        query = query.eq(DbColumns.revision, expectedRevision);
      }

      final List<Map<String, Object?>> rows = await query.select(defaultSelect);

      if (rows.isEmpty) {
        if (expectedRevision != null) {
          throw ConflictException(
            message:
                'This record was changed by someone else. '
                'Please reload and try again.',
          );
        }
        throw NotFoundException();
      }

      return fromJson(rows.first);
    } on AppException {
      rethrow;
    } on PostgrestException catch (error, stackTrace) {
      throw ErrorMapper.mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Soft-deletes the row when [softDeleteColumn] is set; otherwise performs a
  /// hard delete (appropriate for lookup/child rows with no soft-delete
  /// column, and for tables where RLS or a trigger refuses it outright when
  /// that is not permitted).
  Future<void> delete(String id) async {
    try {
      if (softDeleteColumn != null) {
        await client
            .from(table)
            .update(<String, Object?>{
              softDeleteColumn!: true,
              DbColumns.deletedAt: DateTime.now().toUtc().toIso8601String(),
            })
            .eq(DbColumns.id, id);
      } else {
        await client.from(table).delete().eq(DbColumns.id, id);
      }
    } on PostgrestException catch (error, stackTrace) {
      throw ErrorMapper.mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Restores a soft-deleted row.
  Future<T> restore(String id) async {
    if (softDeleteColumn == null) {
      throw StateError('$table does not support soft delete');
    }
    return update(id, <String, Object?>{
      softDeleteColumn!: false,
      DbColumns.deletedAt: null,
    });
  }

  /// Total rows matching [params], without fetching any of them — used for a
  /// count badge where the rows themselves are not needed.
  Future<int> count(QueryParams params) async {
    try {
      PostgrestFilterBuilder<PostgrestList> query = client.from(table).select();
      query = _applyFilters(query, params);
      final PostgrestResponse<PostgrestList> response = await query.count(
        CountOption.exact,
      );
      return response.count;
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// Invokes a Postgres RPC function directly, for the atomic business
  /// transactions defined in the migrations. Returns the raw decoded JSON;
  /// the caller (typically a feature service, not this base class) knows how
  /// to interpret its own function's result shape.
  Future<Object?> rpc(String function, [Map<String, Object?>? params]) async {
    try {
      return await client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error, stackTrace) {
      throw ErrorMapper.mapPostgrestException(error, stackTrace);
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  // ------------------------------------------------------------- internals

  PostgrestFilterBuilder<PostgrestList> _applyFilters(
    PostgrestFilterBuilder<PostgrestList> query,
    QueryParams params,
  ) {
    if (!params.includeDeleted && softDeleteColumn != null) {
      query = query.eq(softDeleteColumn!, false);
    }

    if (params.showroomId != null) {
      query = query.eq(DbColumns.showroomId, params.showroomId!);
    }

    for (final QueryFilter filter in params.filters) {
      query = _applyOneFilter(query, filter);
    }

    final String? search = params.searchExpression;
    if (search != null) {
      query = query.or(search);
    }

    if (params.hasDateRange) {
      query = query
          .gte(params.dateColumn!, params.dateRange!.startIso)
          .lte(params.dateColumn!, params.dateRange!.endIso);
    }

    return query;
  }

  PostgrestFilterBuilder<PostgrestList> _applyOneFilter(
    PostgrestFilterBuilder<PostgrestList> query,
    QueryFilter filter,
  ) {
    switch (filter.operator) {
      case FilterOperator.equals:
        return query.eq(filter.column, filter.value as Object);
      case FilterOperator.notEquals:
        return query.neq(filter.column, filter.value as Object);
      case FilterOperator.greaterThan:
        return query.gt(filter.column, filter.value as Object);
      case FilterOperator.greaterOrEqual:
        return query.gte(filter.column, filter.value as Object);
      case FilterOperator.lessThan:
        return query.lt(filter.column, filter.value as Object);
      case FilterOperator.lessOrEqual:
        return query.lte(filter.column, filter.value as Object);
      case FilterOperator.like:
        return query.like(filter.column, filter.value as String);
      case FilterOperator.ilike:
        return query.ilike(filter.column, filter.value as String);
      case FilterOperator.inList:
        return query.inFilter(filter.column, filter.value! as List<Object?>);
      case FilterOperator.isNull:
        return query.isFilter(filter.column, null);
      case FilterOperator.notNull:
        return query.not(filter.column, 'is', null);
      case FilterOperator.contains:
        return query.contains(filter.column, filter.value as Object);
      case FilterOperator.overlaps:
        return query.overlaps(filter.column, filter.value as Object);
    }
  }

  PostgrestTransformBuilder<PostgrestList> _applySort(
    PostgrestFilterBuilder<PostgrestList> query,
    QueryParams params,
  ) {
    if (params.sorts.isEmpty) {
      return query.order(defaultSortColumn, ascending: false);
    }
    PostgrestTransformBuilder<PostgrestList> result = query;
    for (final QuerySort sort in params.sorts) {
      result = result.order(sort.column, ascending: sort.ascending);
    }
    return result;
  }
}
