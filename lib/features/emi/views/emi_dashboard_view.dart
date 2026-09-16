import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_stat_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/emi/controllers/emi_controller.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The collections desk: which instalments are late, which are about to fall
/// due, and a way to record what comes in.
class EmiDashboardView extends GetView<EmiController> {
  const EmiDashboardView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'EMI Collections',
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Summary(),
          AppSpacing.gapLg,
          const _ViewSwitcher(),
          AppSpacing.gapLg,
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<EmiScheduleModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: AppEmptyState(
                  title: switch (controller.view.value) {
                    EmiView.overdue => 'Nothing overdue',
                    EmiView.dueSoon => 'Nothing due in the next two weeks',
                    EmiView.all => 'No outstanding instalments',
                  },
                  message:
                      'Instalments appear here as financed sales are '
                      'booked and their schedules come due.',
                  icon: Icons.event_available_outlined,
                ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<EmiScheduleModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, EmiScheduleModel e) =>
                                _EmiCard(emi: e),
                        columns: <AppDataColumn<EmiScheduleModel>>[
                          AppDataColumn<EmiScheduleModel>(
                            label: 'Due',
                            sortKey: 'due_date',
                            cellBuilder:
                                (BuildContext context, EmiScheduleModel e) =>
                                    Text(
                                      e.formattedDueDate,
                                      style: e.isOverdue
                                          ? const TextStyle(
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.w600,
                                            )
                                          : null,
                                    ),
                          ),
                          AppDataColumn<EmiScheduleModel>(
                            label: 'Customer',
                            cellBuilder: (_, EmiScheduleModel e) =>
                                Text(e.customerName ?? '-'),
                          ),
                          AppDataColumn<EmiScheduleModel>(
                            label: 'Loan',
                            cellBuilder: (_, EmiScheduleModel e) =>
                                Text(e.loanNumber ?? '-'),
                          ),
                          AppDataColumn<EmiScheduleModel>(
                            label: 'EMI',
                            sortKey: 'emi_number',
                            cellBuilder: (_, EmiScheduleModel e) =>
                                Text(e.label),
                          ),
                          AppDataColumn<EmiScheduleModel>(
                            label: 'Amount due',
                            numeric: true,
                            cellBuilder: (_, EmiScheduleModel e) =>
                                Text(e.formattedDue),
                          ),
                          AppDataColumn<EmiScheduleModel>(
                            label: 'Late by',
                            numeric: true,
                            cellBuilder: (_, EmiScheduleModel e) =>
                                Text(e.isOverdue ? '${e.daysOverdue} d' : '-'),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, EmiScheduleModel e) =>
                                _RowActions(emi: e),
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

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final EmiController controller = Get.find<EmiController>();
    return Obx(() {
      if (controller.response.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          SizedBox(
            width: 200,
            child: AppStatCard(
              label: 'Instalments shown',
              value: '${controller.response.value.totalCount}',
            ),
          ),
          SizedBox(
            width: 200,
            child: AppStatCard(
              label: 'Overdue on this page',
              value: '${controller.overdueCount}',
              accentColor: controller.overdueCount > 0
                  ? AppColors.danger
                  : null,
            ),
          ),
          SizedBox(
            width: 220,
            child: AppStatCard(
              // Deliberately "on this page": summing every outstanding
              // instalment would need its own aggregate query, and a figure
              // that silently covered only part of the book would be worse
              // than one that says what it covers.
              label: 'Due on this page',
              value: MoneyUtil.formatCompact(controller.totalDue),
            ),
          ),
        ],
      );
    });
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher();

  @override
  Widget build(BuildContext context) {
    final EmiController controller = Get.find<EmiController>();
    return Obx(
      () => Wrap(
        spacing: AppSpacing.sm,
        children: <Widget>[
          for (final EmiView view in EmiView.values)
            ChoiceChip(
              label: Text(view.label),
              selected: controller.view.value == view,
              onSelected: (bool selected) {
                if (selected) {
                  controller.showView(view);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.emi});

  final EmiScheduleModel emi;

  @override
  Widget build(BuildContext context) {
    if (emi.isPaid) {
      return const SizedBox.shrink();
    }
    return AppPermissionView(
      permission: AppPermissions.emiPayment,
      child: AppIconButton(
        icon: Icons.payments_outlined,
        tooltip: 'Record payment',
        onPressed: () => Get.dialog<void>(_CollectDialog(emi: emi)),
      ),
    );
  }
}

/// Collects one instalment.
///
/// The amount defaults to what is actually owed, penalty included, because
/// that is the figure quoted on the phone.
class _CollectDialog extends StatefulWidget {
  const _CollectDialog({required this.emi});

  final EmiScheduleModel emi;

  @override
  State<_CollectDialog> createState() => _CollectDialogState();
}

class _CollectDialogState extends State<_CollectDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.emi.amountDue.toStringAsFixed(2),
  );
  final TextEditingController _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  String? _error;

  bool get _requiresReference =>
      _method != PaymentMethod.cash && _method != PaymentMethod.mixed;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (_requiresReference && _reference.text.trim().length < 4) {
      // `record_payment` refuses a non-cash tender with no reference.
      setState(
        () => _error = 'A reference number is required for this method.',
      );
      return;
    }
    setState(() => _error = null);

    final bool recorded = await Get.find<EmiController>().recordEmiPayment(
      emi: widget.emi,
      amount: amount,
      method: _method,
      reference: _reference.text,
    );
    if (recorded) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Collect ${widget.emi.label}'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.emi.customerName ?? 'Unknown customer',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                AppSpacing.gapXs,
                Text(
                  'Due ${widget.emi.formattedDueDate} - '
                  'instalment ${widget.emi.formattedEmi}'
                  '${widget.emi.penaltyAmount > 0 ? " + penalty ${widget.emi.formattedPenalty}" : ""}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,
          AppTextField.money(
            label: 'Amount',
            controller: _amount,
            errorText: _error,
          ),
          AppSpacing.gapLg,
          AppDropdown<PaymentMethod>(
            label: 'Method',
            items: PaymentMethod.values,
            itemLabel: (PaymentMethod m) => m.label,
            value: _method,
            onChanged: (PaymentMethod? m) {
              if (m != null) {
                setState(() => _method = m);
              }
            },
          ),
          AppSpacing.gapLg,
          AppTextField(
            label: 'Reference',
            controller: _reference,
            isRequired: _requiresReference,
            hint: 'Cheque / UPI / approval code',
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      Obx(
        () => AppButton.primary(
          label: 'Record',
          isLoading: Get.find<EmiController>().isRecording.value,
          onPressed: _save,
        ),
      ),
    ],
  );
}

class _EmiCard extends StatelessWidget {
  const _EmiCard({required this.emi});

  final EmiScheduleModel emi;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                emi.customerName ?? 'Unknown customer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              emi.status.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: emi.isOverdue ? AppColors.danger : null,
              ),
            ),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          '${emi.loanNumber ?? "-"} - ${emi.label} - due ${emi.formattedDueDate}'
          '${emi.isOverdue ? " (${emi.daysOverdue} days late)" : ""}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              emi.formattedDue,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            _RowActions(emi: emi),
          ],
        ),
      ],
    ),
  );
}
