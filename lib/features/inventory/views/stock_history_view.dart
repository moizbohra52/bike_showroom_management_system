import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/features/inventory/controllers/stock_history_controller.dart';
import 'package:bike_showroom_management_system/features/inventory/models/stock_movement_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Every stock movement, newest first — for one unit or for the whole branch.
///
/// Read-only by construction: the rows come from the `record_stock_movement`
/// trigger, so there is nothing here to edit or delete. That is the point of
/// the screen.
class StockHistoryView extends GetView<StockHistoryController> {
  const StockHistoryView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: controller.title,
    body: AppContentContainer(
      child: Obx(
        () => AppAsyncBuilder<StockMovementModel>(
          isLoading: controller.isLoading.value,
          error: controller.error.value,
          isEmpty: controller.response.value.isEmpty,
          hasData: controller.response.value.isNotEmpty,
          onRetry: controller.reload,
          emptyState: const AppEmptyState(
            title: 'No movements recorded',
            message:
                'Stock movements appear here as units are taken in, '
                'reserved, transferred or sold.',
            icon: Icons.history,
          ),
          builder: (BuildContext context) => Column(
            children: <Widget>[
              Expanded(
                child: AppDataTable<StockMovementModel>(
                  items: controller.response.value.items,
                  sorts: controller.params.value.sorts,
                  onSort: controller.sortBy,
                  mobileCardBuilder:
                      (BuildContext context, StockMovementModel m) =>
                          _MovementCard(movement: m),
                  columns: <AppDataColumn<StockMovementModel>>[
                    AppDataColumn<StockMovementModel>(
                      label: 'When',
                      sortKey: 'created_at',
                      cellBuilder: (_, StockMovementModel m) =>
                          Text(DateUtil.formatDateTime(m.createdAt)),
                    ),
                    AppDataColumn<StockMovementModel>(
                      label: 'Stock code',
                      cellBuilder: (_, StockMovementModel m) =>
                          Text(m.stockCode ?? '-'),
                    ),
                    AppDataColumn<StockMovementModel>(
                      label: 'Movement',
                      sortKey: 'movement_type',
                      cellBuilder: (_, StockMovementModel m) =>
                          Text(m.movementType.label),
                    ),
                    AppDataColumn<StockMovementModel>(
                      label: 'Transition',
                      cellBuilder: (_, StockMovementModel m) =>
                          Text(m.transition),
                    ),
                    AppDataColumn<StockMovementModel>(
                      label: 'By',
                      cellBuilder: (_, StockMovementModel m) =>
                          Text(m.createdByName ?? '-'),
                    ),
                    AppDataColumn<StockMovementModel>(
                      label: 'Notes',
                      cellBuilder: (_, StockMovementModel m) =>
                          Text(m.notes ?? '-'),
                    ),
                  ],
                ),
              ),
              AppPagination(
                response: controller.response.value,
                onPageChanged: controller.goToPage,
                onPageSizeChanged: controller.setPageSize,
                compact: context.isCompact,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});

  final StockMovementModel movement;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                movement.movementType.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              DateUtil.formatDateTime(movement.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${movement.stockCode ?? "-"} - ${movement.transition}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (movement.notes != null && movement.notes!.isNotEmpty) ...<Widget>[
          AppSpacing.gapXs,
          Text(movement.notes!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}
