import 'package:bike_showroom_management_system/common/models/query_params.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

/// The pager shown beneath a list: "Showing 21-40 of 97", page stepper and,
/// where there is room, a page-size picker.
class AppPagination extends StatelessWidget {
  const AppPagination({
    required this.response,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.compact = false,
    super.key,
  });

  final PaginatedResponse<Object?> response;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  /// Hides the page-size picker and shortens the range label, for a mobile
  /// footer where horizontal space is tight.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          Text(response.rangeLabel, style: theme.textTheme.bodySmall),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!compact && onPageSizeChanged != null) ...<Widget>[
                Text('Rows per page', style: theme.textTheme.bodySmall),
                AppSpacing.hGapSm,
                DropdownButton<int>(
                  value: response.pageSize,
                  underline: const SizedBox.shrink(),
                  items: AppConstants.pageSizeOptions
                      .map(
                        (int size) => DropdownMenuItem<int>(
                          value: size,
                          child: Text(
                            '$size',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (int? size) {
                    if (size != null) {
                      onPageSizeChanged!(size);
                    }
                  },
                ),
                AppSpacing.hGapLg,
              ],
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous page',
                visualDensity: VisualDensity.compact,
                onPressed: response.hasPreviousPage
                    ? () => onPageChanged(response.page - 1)
                    : null,
              ),
              Text(
                '${response.page} / ${response.pageCount}',
                style: theme.textTheme.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next page',
                visualDensity: VisualDensity.compact,
                onPressed: response.hasNextPage
                    ? () => onPageChanged(response.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
