import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:flutter/material.dart';

/// Describes one column of an [AppDataTable].
///
/// Sorting is server-side: tapping a sortable header calls back with
/// [sortKey] rather than reordering the in-memory list, because the whole
/// point of paginating on the server is that the other pages of rows are not
/// in memory to sort.
class AppDataColumn<T> {
  const AppDataColumn({
    required this.label,
    required this.cellBuilder,
    this.sortKey,
    this.numeric = false,
    this.width,
  });

  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;

  /// Server-side column name to sort by. Null means this column cannot be
  /// sorted (an action column, a computed value).
  final String? sortKey;
  final bool numeric;

  /// Fixed width on desktop. Null lets the column size to its content.
  final double? width;
}

/// A list presented as a data table on desktop/web and as a card list on
/// mobile/tablet.
///
/// Per specification section 60: a desktop table forced onto a phone screen
/// is unusable, so the two are genuinely different widgets, chosen by
/// [AppResponsiveLayout] rather than one widget squeezed to fit.
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    required this.items,
    required this.columns,
    required this.mobileCardBuilder,
    this.sorts = const <QuerySort>[],
    this.onSort,
    this.onRowTap,
    this.rowActionsBuilder,
    super.key,
  });

  final List<T> items;
  final List<AppDataColumn<T>> columns;

  /// Card representation for a single row on mobile/tablet.
  final Widget Function(BuildContext context, T row) mobileCardBuilder;

  /// Currently applied sorts, so the desktop header can show the right arrow.
  final List<QuerySort> sorts;

  final ValueChanged<String>? onSort;
  final void Function(T row)? onRowTap;

  /// Optional trailing action column (edit/delete icon buttons), appended
  /// after the declared columns on desktop and rendered by the card itself
  /// on mobile.
  final Widget Function(BuildContext context, T row)? rowActionsBuilder;

  SortDirection? _directionFor(String? sortKey) {
    if (sortKey == null) {
      return null;
    }
    for (final QuerySort sort in sorts) {
      if (sort.column == sortKey) {
        return sort.direction;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AppResponsiveLayout(
    mobile: (BuildContext context) => _MobileList<T>(
      items: items,
      cardBuilder: mobileCardBuilder,
      onRowTap: onRowTap,
    ),
    desktop: (BuildContext context) => _DesktopTable<T>(
      items: items,
      columns: columns,
      onRowTap: onRowTap,
      rowActionsBuilder: rowActionsBuilder,
      onSort: onSort,
      directionFor: _directionFor,
    ),
  );
}

class _MobileList<T> extends StatelessWidget {
  const _MobileList({
    required this.items,
    required this.cardBuilder,
    this.onRowTap,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T row) cardBuilder;
  final void Function(T row)? onRowTap;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.lg),
    itemCount: items.length,
    separatorBuilder: (_, _) => AppSpacing.gapSm,
    itemBuilder: (BuildContext context, int index) {
      final T item = items[index];
      final Widget card = cardBuilder(context, item);
      if (onRowTap == null) {
        return card;
      }
      return InkWell(
        onTap: () => onRowTap!(item),
        borderRadius: AppRadius.lgAll,
        child: card,
      );
    },
  );
}

class _DesktopTable<T> extends StatelessWidget {
  const _DesktopTable({
    required this.items,
    required this.columns,
    required this.directionFor,
    this.onRowTap,
    this.rowActionsBuilder,
    this.onSort,
  });

  final List<T> items;
  final List<AppDataColumn<T>> columns;
  final SortDirection? Function(String? sortKey) directionFor;
  final void Function(T row)? onRowTap;
  final Widget Function(BuildContext context, T row)? rowActionsBuilder;
  final ValueChanged<String>? onSort;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width),
        child: DataTable(
          columns: <DataColumn>[
            for (final AppDataColumn<T> column in columns)
              DataColumn(
                numeric: column.numeric,
                label: Expanded(child: Text(column.label)),
                onSort: column.sortKey == null || onSort == null
                    ? null
                    : (int _, bool _) => onSort!(column.sortKey!),
              ),
            if (rowActionsBuilder != null) const DataColumn(label: Text('')),
          ],
          sortColumnIndex: _sortColumnIndex(),
          sortAscending: _sortAscending(),
          rows: <DataRow>[
            for (final T item in items)
              DataRow(
                onSelectChanged: onRowTap == null
                    ? null
                    : (bool? _) => onRowTap!(item),
                cells: <DataCell>[
                  for (final AppDataColumn<T> column in columns)
                    DataCell(column.cellBuilder(context, item)),
                  if (rowActionsBuilder != null)
                    DataCell(rowActionsBuilder!(context, item)),
                ],
              ),
          ],
          headingRowColor: WidgetStatePropertyAll<Color>(
            theme.colorScheme.surfaceContainerHigh,
          ),
        ),
      ),
    );
  }

  int? _sortColumnIndex() {
    for (int i = 0; i < columns.length; i++) {
      if (directionFor(columns[i].sortKey) != null) {
        return i;
      }
    }
    return null;
  }

  bool _sortAscending() {
    for (final AppDataColumn<T> column in columns) {
      final SortDirection? direction = directionFor(column.sortKey);
      if (direction != null) {
        return direction.isAscending;
      }
    }
    return true;
  }
}
