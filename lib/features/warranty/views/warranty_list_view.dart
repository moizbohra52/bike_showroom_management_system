import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/warranty/controllers/warranty_controller.dart';
import 'package:bike_showroom_management_system/features/warranty/models/warranty_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Warranties on customer vehicles.
class WarrantyListView extends GetView<WarrantyController> {
  const WarrantyListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Warranty',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: AppButton.ghost(
          label: 'Claims',
          icon: Icons.assignment_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.warrantyClaims),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: _Filters(),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<WarrantyModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No warranties yet',
                        message:
                            'A standard warranty is created automatically when '
                            'a vehicle is sold.',
                        icon: Icons.verified_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<WarrantyModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, WarrantyModel w) =>
                                _WarrantyCard(warranty: w),
                        columns: <AppDataColumn<WarrantyModel>>[
                          AppDataColumn<WarrantyModel>(
                            label: 'Vehicle',
                            cellBuilder: (_, WarrantyModel w) =>
                                Text(w.vehicleLabel),
                          ),
                          AppDataColumn<WarrantyModel>(
                            label: 'Customer',
                            cellBuilder: (_, WarrantyModel w) =>
                                Text(w.customerName ?? '-'),
                          ),
                          AppDataColumn<WarrantyModel>(
                            label: 'Cover',
                            sortKey: 'warranty_type',
                            cellBuilder: (_, WarrantyModel w) =>
                                Text(w.warrantyType.label),
                          ),
                          AppDataColumn<WarrantyModel>(
                            label: 'Expires',
                            sortKey: 'end_date',
                            cellBuilder:
                                (BuildContext context, WarrantyModel w) => Text(
                                  w.formattedEndDate,
                                  style: w.isExpired
                                      ? const TextStyle(
                                          color: AppColors.danger,
                                        )
                                      : w.isExpiringSoon
                                      ? const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                ),
                          ),
                          AppDataColumn<WarrantyModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, WarrantyModel w) =>
                                AppStatusChip(status: w.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, WarrantyModel w) =>
                                _RowActions(warranty: w),
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
  );
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final WarrantyController controller = Get.find<WarrantyController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<WarrantyStatus>(
              label: 'Status',
              hint: 'All',
              items: WarrantyStatus.values,
              itemLabel: (WarrantyStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: Obx(
            () => AppDropdown<WarrantyType>(
              label: 'Cover',
              hint: 'All',
              items: WarrantyType.values,
              itemLabel: (WarrantyType t) => t.label,
              value: controller.typeFilter.value,
              onChanged: controller.filterByType,
            ),
          ),
        ),
        AppButton.ghost(
          label: 'Expiring soon',
          icon: Icons.schedule_outlined,
          size: AppButtonSize.small,
          onPressed: controller.showExpiring,
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.warranty});

  final WarrantyModel warranty;

  @override
  Widget build(BuildContext context) {
    // Cover that has lapsed or been voided covers nothing, so a claim against
    // it would only have to be rejected.
    if (!warranty.acceptsClaim) {
      return const SizedBox.shrink();
    }
    return AppPermissionView(
      permission: AppPermissions.warrantyClaim,
      child: AppIconButton(
        icon: Icons.assignment_add,
        tooltip: 'Raise a claim',
        onPressed: () => showClaimDialog(warranty),
      ),
    );
  }
}

/// Raises a claim against [warranty].
Future<void> showClaimDialog(WarrantyModel warranty) =>
    Get.dialog<void>(_ClaimDialog(warranty: warranty));

class _ClaimDialog extends StatefulWidget {
  const _ClaimDialog({required this.warranty});

  final WarrantyModel warranty;

  @override
  State<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<_ClaimDialog> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // The claim list owns the write, so the new claim lands in the list the
    // user will look at next.
    final WarrantyClaimController controller =
        Get.isRegistered<WarrantyClaimController>()
        ? Get.find<WarrantyClaimController>()
        : Get.put(
            WarrantyClaimController(
              repository: Get.find(),
              warrantyRepository: Get.find(),
            ),
          );

    final bool raised = await controller.raise(
      warranty: widget.warranty,
      description: _description.text,
      claimAmount: double.tryParse(_amount.text.trim()) ?? 0,
    );
    if (raised) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Claim - ${widget.warranty.vehicleLabel}'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppCard(
            child: Text(
              '${widget.warranty.warrantyType.label} cover, valid to '
              '${widget.warranty.formattedEndDate}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          AppSpacing.gapLg,
          AppTextField.multiline(
            label: 'Fault',
            controller: _description,
            maxLines: 3,
            isRequired: true,
            hint: 'What failed, and what was replaced',
          ),
          AppSpacing.gapLg,
          AppTextField.money(
            label: 'Amount claimed',
            controller: _amount,
            isRequired: false,
            helper: 'What the manufacturer allows may be less',
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      AppButton.primary(label: 'Submit claim', onPressed: _save),
    ],
  );
}

class _WarrantyCard extends StatelessWidget {
  const _WarrantyCard({required this.warranty});

  final WarrantyModel warranty;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                warranty.vehicleLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: warranty.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${warranty.warrantyType.label} - ${warranty.customerName ?? "-"}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              'To ${warranty.formattedEndDate}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: warranty.isExpired
                    ? AppColors.danger
                    : warranty.isExpiringSoon
                    ? AppColors.warning
                    : null,
              ),
            ),
            const Spacer(),
            _RowActions(warranty: warranty),
          ],
        ),
      ],
    ),
  );
}
