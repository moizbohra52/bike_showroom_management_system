import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/warranty/controllers/warranty_controller.dart';
import 'package:bike_showroom_management_system/features/warranty/models/warranty_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Warranty claims raised with the manufacturer.
class WarrantyClaimListView extends GetView<WarrantyClaimController> {
  const WarrantyClaimListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Warranty Claims',
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
              () => AppAsyncBuilder<WarrantyClaimModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No claims yet',
                        message:
                            'Raise a claim from a vehicle warranty when a '
                            'covered component fails.',
                        icon: Icons.assignment_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<WarrantyClaimModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, WarrantyClaimModel c) =>
                                _ClaimCard(claim: c),
                        columns: <AppDataColumn<WarrantyClaimModel>>[
                          AppDataColumn<WarrantyClaimModel>(
                            label: 'Claim',
                            sortKey: 'claim_number',
                            cellBuilder: (_, WarrantyClaimModel c) =>
                                Text(c.claimNumber),
                          ),
                          AppDataColumn<WarrantyClaimModel>(
                            label: 'Date',
                            sortKey: 'claim_date',
                            cellBuilder: (_, WarrantyClaimModel c) =>
                                Text(c.formattedDate),
                          ),
                          AppDataColumn<WarrantyClaimModel>(
                            label: 'Vehicle',
                            cellBuilder: (_, WarrantyClaimModel c) =>
                                Text(c.vehicleLabel ?? '-'),
                          ),
                          AppDataColumn<WarrantyClaimModel>(
                            label: 'Claimed',
                            sortKey: 'claim_amount',
                            numeric: true,
                            cellBuilder: (_, WarrantyClaimModel c) =>
                                Text(c.formattedClaimAmount),
                          ),
                          AppDataColumn<WarrantyClaimModel>(
                            label: 'Approved',
                            sortKey: 'approved_amount',
                            numeric: true,
                            cellBuilder:
                                (
                                  BuildContext context,
                                  WarrantyClaimModel c,
                                ) => Text(
                                  c.formattedApprovedAmount,
                                  // The gap is what the showroom absorbs.
                                  style: c.shortfall > 0.01
                                      ? const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                        )
                                      : null,
                                ),
                          ),
                          AppDataColumn<WarrantyClaimModel>(
                            label: 'Status',
                            sortKey: 'status',
                            cellBuilder: (_, WarrantyClaimModel c) =>
                                AppStatusChip(status: c.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, WarrantyClaimModel c) =>
                                _RowActions(claim: c),
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
    final WarrantyClaimController controller =
        Get.find<WarrantyClaimController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 320,
          child: AppSearchField(
            hint: 'Search claim number or fault',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 220,
          child: Obx(
            () => AppDropdown<WarrantyClaimStatus>(
              label: 'Status',
              hint: 'All',
              items: WarrantyClaimStatus.values,
              itemLabel: (WarrantyClaimStatus s) => s.label,
              value: controller.statusFilter.value,
              onChanged: controller.filterByStatus,
            ),
          ),
        ),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.claim});

  final WarrantyClaimModel claim;

  @override
  Widget build(BuildContext context) {
    if (!claim.isOpen) {
      return const SizedBox.shrink();
    }
    return AppPermissionView(
      permission: AppPermissions.warrantyApprove,
      child: AppIconButton(
        icon: Icons.gavel_outlined,
        tooltip: 'Record the decision',
        onPressed: () => Get.dialog<void>(_SettleDialog(claim: claim)),
      ),
    );
  }
}

/// Records what the manufacturer decided.
class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.claim});

  final WarrantyClaimModel claim;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final TextEditingController _approved = TextEditingController(
    text: widget.claim.claimAmount.toStringAsFixed(2),
  );
  final TextEditingController _resolution = TextEditingController();
  WarrantyClaimStatus _status = WarrantyClaimStatus.approved;

  /// The states a decision can land in. DRAFT and SUBMITTED are where a claim
  /// starts, not where it ends.
  static const List<WarrantyClaimStatus> _outcomes = <WarrantyClaimStatus>[
    WarrantyClaimStatus.underReview,
    WarrantyClaimStatus.approved,
    WarrantyClaimStatus.rejected,
    WarrantyClaimStatus.settled,
  ];

  @override
  void dispose() {
    _approved.dispose();
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool saved = await Get.find<WarrantyClaimController>().settle(
      claim: widget.claim,
      status: _status,
      approvedAmount: _status == WarrantyClaimStatus.rejected
          ? 0
          : double.tryParse(_approved.text.trim()),
      resolution: _resolution.text,
    );
    if (saved) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Claim ${widget.claim.claimNumber}'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.claim.description),
                AppSpacing.gapXs,
                Text(
                  'Claimed ${MoneyUtil.format(widget.claim.claimAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppDropdown<WarrantyClaimStatus>(
            label: 'Outcome',
            items: _outcomes,
            itemLabel: (WarrantyClaimStatus s) => s.label,
            value: _status,
            isRequired: true,
            onChanged: (WarrantyClaimStatus? s) {
              if (s != null) {
                setState(() => _status = s);
              }
            },
          ),
          AppSpacing.gapLg,
          AppTextField.money(
            label: 'Amount approved',
            controller: _approved,
            isRequired: false,
            isEnabled: _status != WarrantyClaimStatus.rejected,
            helper: 'Anything less than claimed is absorbed by the showroom',
          ),
          AppSpacing.gapLg,
          AppTextField.multiline(
            label: 'Resolution',
            controller: _resolution,
            maxLines: 2,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      Obx(
        () => AppButton.primary(
          label: 'Record',
          isLoading: Get.find<WarrantyClaimController>().isSaving.value,
          onPressed: _save,
        ),
      ),
    ],
  );
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim});

  final WarrantyClaimModel claim;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                claim.claimNumber,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: claim.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${claim.vehicleLabel ?? "-"} - ${claim.customerName ?? "-"}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapXs,
        Text(
          claim.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              'Claimed ${claim.formattedClaimAmount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              claim.formattedApprovedAmount,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            _RowActions(claim: claim),
          ],
        ),
      ],
    ),
  );
}
