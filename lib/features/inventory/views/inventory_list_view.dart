import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_stat_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/inventory/controllers/inventory_controller.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Stock on the active branch's floor, one row per physical machine.
class InventoryListView extends GetView<InventoryController> {
  const InventoryListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Inventory',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppButton.ghost(
          label: 'History',
          icon: Icons.history,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.stockHistory),
        ),
      ),
      AppPermissionView(
        permission: AppPermissions.inventoryCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Stock',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => _openForm(),
          ),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _StatusSummary(),
          AppSpacing.gapLg,
          const _Filters(),
          AppSpacing.gapLg,
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<InventoryModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No stock yet',
                        message:
                            'Add the machines on your floor. Each unit is '
                            'tracked by its own chassis and engine number.',
                        icon: Icons.inventory_2_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<InventoryModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openForm,
                        mobileCardBuilder:
                            (BuildContext context, InventoryModel unit) =>
                                _UnitCard(unit: unit),
                        columns: <AppDataColumn<InventoryModel>>[
                          AppDataColumn<InventoryModel>(
                            label: 'Stock code',
                            sortKey: 'stock_code',
                            cellBuilder: (_, InventoryModel u) =>
                                Text(u.stockCode),
                          ),
                          AppDataColumn<InventoryModel>(
                            label: 'Vehicle',
                            cellBuilder: (_, InventoryModel u) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (u.colorHex != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.sm,
                                    ),
                                    child: _Swatch(hex: u.colorHex!),
                                  ),
                                Flexible(child: Text(u.displayName)),
                              ],
                            ),
                          ),
                          AppDataColumn<InventoryModel>(
                            label: 'Chassis',
                            sortKey: 'chassis_number',
                            cellBuilder: (_, InventoryModel u) =>
                                Text(u.chassisNumber),
                          ),
                          AppDataColumn<InventoryModel>(
                            label: 'Age',
                            numeric: true,
                            cellBuilder: (BuildContext context, InventoryModel u) {
                              // Ageing stock is capital standing still, so it
                              // is called out rather than left to be noticed.
                              final bool ageing = u.ageInDays > 90 && !u.isSold;
                              return Text(
                                '${u.ageInDays} d',
                                style: ageing
                                    ? TextStyle(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : null,
                              );
                            },
                          ),
                          AppDataColumn<InventoryModel>(
                            label: 'Purchase',
                            sortKey: 'purchase_price',
                            numeric: true,
                            cellBuilder: (_, InventoryModel u) =>
                                Text(u.formattedPurchasePrice),
                          ),
                          AppDataColumn<InventoryModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, InventoryModel u) =>
                                AppStatusChip(status: u.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, InventoryModel u) =>
                                _RowActions(unit: u),
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
        ],
      ),
    ),
    floatingActionButton: context.isCompact
        ? AppPermissionView(
            permission: AppPermissions.inventoryCreate,
            child: FloatingActionButton(
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  static Future<void> _openForm([InventoryModel? unit]) async {
    final Object? result = await Get.toNamed(
      AppRoutes.inventoryForm,
      arguments: unit,
    );
    if (result is InventoryModel) {
      final InventoryController controller = Get.find<InventoryController>();
      await controller.reload();
      await controller.loadCounts();
    }
  }
}

/// Counts per status, doubling as a one-tap filter.
class _StatusSummary extends StatelessWidget {
  const _StatusSummary();

  /// The statuses worth a tile. Showing all seven would push the list below
  /// the fold for the sake of numbers that are usually zero.
  static const List<InventoryStatus> _shown = <InventoryStatus>[
    InventoryStatus.available,
    InventoryStatus.reserved,
    InventoryStatus.demo,
    InventoryStatus.inTransit,
    InventoryStatus.sold,
  ];

  @override
  Widget build(BuildContext context) {
    final InventoryController controller = Get.find<InventoryController>();
    return Obx(() {
      if (controller.counts.isEmpty) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          for (final InventoryStatus status in _shown)
            SizedBox(
              width: 180,
              child: AppStatCard(
                label: status.label,
                value: '${controller.counts[status] ?? 0}',
                accentColor: controller.statusFilter.value == status
                    ? AppColors.primary
                    : null,
                onTap: () => controller.filterByStatus(
                  controller.statusFilter.value == status ? null : status,
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final InventoryController controller = Get.find<InventoryController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 320,
          child: AppSearchField(
            hint: 'Search stock code, chassis or engine number',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<InventoryStatus>(
              label: 'Status',
              hint: 'All statuses',
              items: InventoryStatus.values,
              itemLabel: (InventoryStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    final String cleaned = hex.replaceFirst('#', '');
    final int? value = int.tryParse(cleaned, radix: 16);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: value == null
            ? Theme.of(context).disabledColor
            : Color(0xFF000000 | value),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.unit});

  final InventoryModel unit;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      AppPermissionView(
        permission: AppPermissions.inventoryEdit,
        child: AppIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          onPressed: () => InventoryListView._openForm(unit),
        ),
      ),
      AppPermissionView(
        permission: AppPermissions.inventoryAdjust,
        child: AppIconButton(
          icon: Icons.swap_horiz,
          tooltip: 'Change status',
          // A sold unit is terminal: reversing it belongs to cancelling the
          // sale, which restores the stock through its own transaction.
          isEnabled: !unit.isSold,
          onPressed: () => Get.dialog<void>(_AdjustDialog(unit: unit)),
        ),
      ),
      AppIconButton(
        icon: Icons.history,
        tooltip: 'Movement history',
        onPressed: () => Get.toNamed(AppRoutes.stockHistory, arguments: unit),
      ),
    ],
  );
}

/// Collects the new status and the reason, both of which `adjust_inventory`
/// requires — an unexplained stock movement is exactly what the audit trail
/// exists to prevent.
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.unit});

  final InventoryModel unit;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late InventoryStatus _status = widget.unit.status;
  final TextEditingController _reason = TextEditingController();
  bool _isSaving = false;
  String? _reasonError;

  /// `adjust_inventory` rejects anything shorter. Matching it here turns a
  /// server exception into a message beside the field.
  static const int _minReasonLength = 5;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_reason.text.trim().length < _minReasonLength) {
      setState(
        () => _reasonError =
            'Give a reason of at least $_minReasonLength characters.',
      );
      return;
    }
    setState(() {
      _reasonError = null;
      _isSaving = true;
    });
    await Get.find<InventoryController>().adjust(
      unit: widget.unit,
      newStatus: _status,
      reason: _reason.text.trim(),
    );
    if (mounted) {
      setState(() => _isSaving = false);
    }
    Get.back<void>();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Change status - ${widget.unit.stockCode}'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppDropdown<InventoryStatus>(
            label: 'New status',
            // SOLD is omitted: a unit becomes sold by being sold, through
            // `create_sale_transaction`, not by someone setting a field.
            items: InventoryStatus.values
                .where((InventoryStatus s) => s != InventoryStatus.sold)
                .toList(),
            itemLabel: (InventoryStatus s) => s.label,
            value: _status,
            isRequired: true,
            onChanged: (InventoryStatus? value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          AppSpacing.gapLg,
          AppTextField.multiline(
            label: 'Reason',
            controller: _reason,
            maxLines: 2,
            isRequired: true,
            hint: 'Why is this unit moving?',
            errorText: _reasonError,
            // The reason is stored on the unit itself, replacing whatever
            // note it carried. The movement row records the transition.
            helper: "Replaces this unit's notes.",
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      AppButton.primary(label: 'Apply', isLoading: _isSaving, onPressed: _save),
    ],
  );
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit});

  final InventoryModel unit;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => InventoryListView._openForm(unit),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                unit.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: unit.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${unit.stockCode} - ${unit.chassisNumber}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              unit.formattedPurchasePrice,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            Text(
              '${unit.ageInDays} days in stock',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    ),
  );
}
