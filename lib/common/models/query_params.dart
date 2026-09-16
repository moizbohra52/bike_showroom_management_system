import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';

/// A single filter clause, mapped onto a PostgREST operator.
class QueryFilter {
  const QueryFilter({
    required this.column,
    required this.operator,
    required this.value,
  });

  /// `column = value`
  const QueryFilter.equals(this.column, this.value)
    : operator = FilterOperator.equals;

  /// `column IN (values)`
  const QueryFilter.inList(this.column, List<Object?> values)
    : operator = FilterOperator.inList,
      value = values;

  /// Case-insensitive contains, for a search box.
  const QueryFilter.contains(this.column, String term)
    : operator = FilterOperator.ilike,
      value = term;

  const QueryFilter.greaterOrEqual(this.column, this.value)
    : operator = FilterOperator.greaterOrEqual;

  const QueryFilter.lessOrEqual(this.column, this.value)
    : operator = FilterOperator.lessOrEqual;

  const QueryFilter.isNull(this.column)
    : operator = FilterOperator.isNull,
      value = null;

  const QueryFilter.notNull(this.column)
    : operator = FilterOperator.notNull,
      value = null;

  final String column;
  final FilterOperator operator;
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is QueryFilter &&
      other.column == column &&
      other.operator == operator &&
      other.value == value;

  @override
  int get hashCode => Object.hash(column, operator, value);

  @override
  String toString() => '$column ${operator.symbol} $value';
}

/// PostgREST filter operators.
enum FilterOperator {
  equals('eq', '='),
  notEquals('neq', '!='),
  greaterThan('gt', '>'),
  greaterOrEqual('gte', '>='),
  lessThan('lt', '<'),
  lessOrEqual('lte', '<='),
  like('like', 'LIKE'),
  ilike('ilike', 'ILIKE'),
  inList('in', 'IN'),
  isNull('is', 'IS NULL'),
  notNull('not.is', 'IS NOT NULL'),
  contains('cs', '@>'),
  overlaps('ov', '&&');

  const FilterOperator(this.postgrestName, this.symbol);

  final String postgrestName;
  final String symbol;
}

/// Sort instruction for a server-side ordered query.
class QuerySort {
  const QuerySort({
    required this.column,
    this.direction = SortDirection.descending,
    this.nullsFirst = false,
  });

  final String column;
  final SortDirection direction;
  final bool nullsFirst;

  bool get ascending => direction.isAscending;

  QuerySort get inverted =>
      QuerySort(column: column, direction: direction.inverted);

  @override
  bool operator ==(Object other) =>
      other is QuerySort &&
      other.column == column &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(column, direction);

  @override
  String toString() => '$column ${direction.value}';
}

/// The complete description of a list query.
///
/// Every paginated repository method takes one of these. Centralising it means
/// pagination, search debouncing, sorting, showroom scoping and soft-delete
/// filtering behave identically across all twenty-plus list screens, and the
/// page-size ceiling in [AppConstants.maxPageSize] cannot be bypassed by a
/// caller passing a large limit.
class QueryParams {
  QueryParams({
    int page = 1,
    int pageSize = AppConstants.defaultPageSize,
    this.searchTerm,
    this.searchColumns = const <String>[],
    this.filters = const <QueryFilter>[],
    this.sorts = const <QuerySort>[],
    this.dateRange,
    this.dateColumn,
    this.showroomId,
    this.includeDeleted = false,
    this.select,
  }) : page = page < 1 ? 1 : page,
       pageSize = pageSize < 1
           ? AppConstants.defaultPageSize
           : (pageSize > AppConstants.maxPageSize
                 ? AppConstants.maxPageSize
                 : pageSize);

  /// One-based page number.
  final int page;

  /// Rows per page, clamped to [AppConstants.maxPageSize].
  final int pageSize;

  /// Free-text term. Ignored unless it reaches
  /// [AppConstants.minSearchLength], so a single keystroke does not scan.
  final String? searchTerm;

  /// Columns the term is matched against, OR-ed together.
  final List<String> searchColumns;

  final List<QueryFilter> filters;
  final List<QuerySort> sorts;

  /// Optional date window, applied to [dateColumn].
  final DateRange? dateRange;
  final String? dateColumn;

  /// Explicit showroom scope. Row Level Security already restricts rows to the
  /// showrooms a user may see; this narrows further to the one they have
  /// selected in the switcher.
  final String? showroomId;

  /// Soft-deleted rows are excluded unless a caller deliberately asks for
  /// them, which only the audit and recycle-bin screens do.
  final bool includeDeleted;

  /// PostgREST `select` expression, including embedded relations.
  final String? select;

  /// Zero-based offset for `range()`.
  int get offset => (page - 1) * pageSize;

  /// Inclusive end index for `range()`.
  int get rangeEnd => offset + pageSize - 1;

  /// Whether the search term is long enough to be worth sending.
  bool get hasSearch {
    final String? term = searchTerm?.trim();
    return term != null &&
        term.length >= AppConstants.minSearchLength &&
        searchColumns.isNotEmpty;
  }

  String get normalisedSearch => searchTerm?.trim() ?? '';

  bool get hasDateRange => dateRange != null && dateColumn != null;

  /// True when anything beyond plain pagination is applied. Drives the
  /// "clear filters" affordance and the empty-state wording.
  bool get hasActiveFilters => hasSearch || filters.isNotEmpty || hasDateRange;

  /// Builds the PostgREST `or=(...)` expression for a multi-column search.
  ///
  /// Commas and parentheses are stripped from the term because they are the
  /// delimiters of the expression itself; leaving them in would let a search
  /// box alter the filter structure.
  String? get searchExpression {
    if (!hasSearch) {
      return null;
    }
    final String sanitised = normalisedSearch
        .replaceAll(RegExp(r'[,()*\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (sanitised.isEmpty) {
      return null;
    }
    return searchColumns
        .map((String column) => '$column.ilike.*$sanitised*')
        .join(',');
  }

  QueryParams copyWith({
    int? page,
    int? pageSize,
    String? searchTerm,
    List<String>? searchColumns,
    List<QueryFilter>? filters,
    List<QuerySort>? sorts,
    DateRange? dateRange,
    String? dateColumn,
    String? showroomId,
    bool? includeDeleted,
    String? select,
    bool clearSearch = false,
    bool clearDateRange = false,
    bool clearShowroom = false,
  }) => QueryParams(
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    searchTerm: clearSearch ? null : (searchTerm ?? this.searchTerm),
    searchColumns: searchColumns ?? this.searchColumns,
    filters: filters ?? this.filters,
    sorts: sorts ?? this.sorts,
    dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    dateColumn: clearDateRange ? null : (dateColumn ?? this.dateColumn),
    showroomId: clearShowroom ? null : (showroomId ?? this.showroomId),
    includeDeleted: includeDeleted ?? this.includeDeleted,
    select: select ?? this.select,
  );

  /// Resets to the first page. Used whenever a filter changes, since staying
  /// on page 7 of a newly filtered result set shows an empty screen.
  QueryParams resetPage() => copyWith(page: 1);

  QueryParams nextPage() => copyWith(page: page + 1);

  QueryParams withFilter(QueryFilter filter) {
    final List<QueryFilter> next =
        filters
            .where((QueryFilter existing) => existing.column != filter.column)
            .toList()
          ..add(filter);
    return copyWith(filters: next).resetPage();
  }

  QueryParams withoutFilter(String column) => copyWith(
    filters: filters
        .where((QueryFilter existing) => existing.column != column)
        .toList(),
  ).resetPage();

  /// Cycles sort on a column: unsorted -> ascending -> descending -> unsorted.
  QueryParams toggleSort(String column) {
    QuerySort? existing;
    for (final QuerySort sort in sorts) {
      if (sort.column == column) {
        existing = sort;
        break;
      }
    }

    if (existing == null) {
      return copyWith(
        sorts: <QuerySort>[
          QuerySort(column: column, direction: SortDirection.ascending),
        ],
      );
    }
    if (existing.direction == SortDirection.ascending) {
      return copyWith(
        sorts: <QuerySort>[
          QuerySort(column: column, direction: SortDirection.descending),
        ],
      );
    }
    return copyWith(sorts: const <QuerySort>[]);
  }

  /// Current direction applied to [column], or null when unsorted. Drives the
  /// sort arrow in a data-table header.
  SortDirection? sortDirectionFor(String column) {
    for (final QuerySort sort in sorts) {
      if (sort.column == column) {
        return sort.direction;
      }
    }
    return null;
  }

  /// Query-string form, for the Dio-based REST path and for cache keys.
  Map<String, String> toQueryMap() {
    final Map<String, String> map = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (hasSearch) {
      map['search'] = normalisedSearch;
    }
    if (showroomId != null) {
      map['showroom_id'] = showroomId!;
    }
    if (hasDateRange) {
      map['from'] = dateRange!.startIso;
      map['to'] = dateRange!.endIso;
      map['date_column'] = dateColumn!;
    }
    for (final QueryFilter filter in filters) {
      map[filter.column] = '${filter.operator.postgrestName}.${filter.value}';
    }
    if (sorts.isNotEmpty) {
      map['order'] = sorts
          .map((QuerySort sort) => '${sort.column}.${sort.direction.value}')
          .join(',');
    }
    return map;
  }

  /// Stable identity for caching a page of results. Deliberately excludes
  /// nothing: two queries with the same key must return the same rows.
  String get cacheKey {
    final StringBuffer buffer = StringBuffer()
      ..write('p$page-s$pageSize')
      ..write('-q${normalisedSearch.toLowerCase()}')
      ..write('-sr${showroomId ?? 'all'}')
      ..write('-d${includeDeleted ? 1 : 0}');
    if (hasDateRange) {
      buffer.write('-dr${dateRange!.startIso}_${dateRange!.endIso}');
    }
    for (final QueryFilter filter in filters) {
      buffer.write(
        '-f${filter.column}${filter.operator.postgrestName}'
        '${filter.value}',
      );
    }
    for (final QuerySort sort in sorts) {
      buffer.write('-o${sort.column}${sort.direction.value}');
    }
    return buffer.toString();
  }

  @override
  String toString() => 'QueryParams($cacheKey)';
}

/// One page of results plus the metadata a pager needs.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    this.isFromCache = false,
    this.fetchedAt,
  });

  const PaginatedResponse.empty({
    this.page = 1,
    this.pageSize = AppConstants.defaultPageSize,
  }) : items = const <Never>[],
       totalCount = 0,
       isFromCache = false,
       fetchedAt = null;

  final List<T> items;

  /// Total matching rows on the server, not just this page. Supplied by
  /// PostgREST's `Content-Range` header via an exact count.
  final int totalCount;

  final int page;
  final int pageSize;

  /// True when served from the local database because the network was
  /// unavailable. The UI shows an "offline copy" indicator in that case.
  final bool isFromCache;

  /// When the data was actually retrieved, for the staleness indicator.
  final DateTime? fetchedAt;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  int get pageCount =>
      totalCount <= 0 ? 1 : ((totalCount + pageSize - 1) ~/ pageSize);

  bool get hasNextPage => page < pageCount;
  bool get hasPreviousPage => page > 1;

  /// One-based index of the first row on this page, for "showing 21-40 of 97".
  int get firstItemIndex => totalCount == 0 ? 0 : (page - 1) * pageSize + 1;

  int get lastItemIndex {
    final int candidate = (page - 1) * pageSize + items.length;
    return candidate > totalCount ? totalCount : candidate;
  }

  String get rangeLabel => totalCount == 0
      ? 'No records'
      : 'Showing $firstItemIndex-$lastItemIndex of $totalCount';

  /// Projects the items through [convert], preserving the page metadata.
  PaginatedResponse<R> map<R>(R Function(T item) convert) =>
      PaginatedResponse<R>(
        items: items.map(convert).toList(growable: false),
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
        isFromCache: isFromCache,
        fetchedAt: fetchedAt,
      );

  PaginatedResponse<T> copyWith({
    List<T>? items,
    int? totalCount,
    int? page,
    int? pageSize,
    bool? isFromCache,
    DateTime? fetchedAt,
  }) => PaginatedResponse<T>(
    items: items ?? this.items,
    totalCount: totalCount ?? this.totalCount,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
    isFromCache: isFromCache ?? this.isFromCache,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );

  @override
  String toString() =>
      'PaginatedResponse(${items.length} of $totalCount, page $page/'
      '$pageCount${isFromCache ? ', cached' : ''})';
}
