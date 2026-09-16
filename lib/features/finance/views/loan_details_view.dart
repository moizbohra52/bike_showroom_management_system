import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_stat_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/emi/models/emi_schedule_model.dart';
import 'package:bike_showroom_management_system/features/finance/controllers/finance_controller.dart';
import 'package:bike_showroom_management_system/features/finance/models/loan_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One finance agreement and its full repayment schedule.
class LoanDetailsView extends GetView<LoanDetailsController> {
  const LoanDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final LoanModel loan = controller.loan;

    return Scaffold(
      appBar: AppBar(title: Text(loan.loanNumber)),
      body: Center(
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: AppContentContainer(
            maxWidth: 900,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Terms(loan: loan),
                AppSpacing.gapXl,
                const _Progress(),
                AppSpacing.gapXl,
                const _Schedule(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms({required this.loan});

  final LoanModel loan;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                loan.customerName ?? 'Unknown customer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: loan.status.value),
          ],
        ),
        AppSpacing.gapMd,
        _Detail(label: 'Financier', value: loan.financeCompanyName ?? '-'),
        if (loan.saleNumber != null)
          _Detail(label: 'Against sale', value: loan.saleNumber!),
        _Detail(label: 'Principal', value: loan.formattedLoanAmount),
        _Detail(
          label: 'Down payment',
          value: MoneyUtil.format(loan.downPayment),
        ),
        _Detail(
          label: 'Interest',
          value:
              '${loan.interestRate.toStringAsFixed(2)}% p.a. '
              '(${loan.interestType.label})',
        ),
        _Detail(label: 'Tenure', value: loan.tenureLabel),
        _Detail(label: 'EMI', value: loan.formattedEmi),
        _Detail(label: 'Start date', value: loan.formattedStartDate),
        const Divider(height: AppSpacing.xxl),
        // Worth stating plainly: on a FLAT agreement the cost of credit is
        // markedly higher than the nominal rate suggests.
        _Detail(
          label: 'Total repayable',
          value: MoneyUtil.format(loan.totalRepayable),
        ),
        _Detail(label: 'Cost of credit', value: loan.formattedTotalInterest),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    final LoanDetailsController controller = Get.find<LoanDetailsController>();
    return Obx(() {
      if (controller.schedule.isEmpty) {
        return const SizedBox.shrink();
      }
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          SizedBox(
            width: 180,
            child: AppStatCard(
              label: 'Instalments paid',
              value: '${controller.paidCount}/${controller.schedule.length}',
            ),
          ),
          SizedBox(
            width: 180,
            child: AppStatCard(
              label: 'Collected',
              value: MoneyUtil.formatCompact(controller.totalPaid),
            ),
          ),
          SizedBox(
            width: 180,
            child: AppStatCard(
              label: 'Outstanding',
              value: MoneyUtil.formatCompact(controller.totalOutstanding),
            ),
          ),
          SizedBox(
            width: 180,
            child: AppStatCard(
              label: 'Overdue',
              value: '${controller.overdueCount}',
              accentColor: controller.overdueCount > 0
                  ? AppColors.danger
                  : null,
            ),
          ),
        ],
      );
    });
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule();

  @override
  Widget build(BuildContext context) {
    final LoanDetailsController controller = Get.find<LoanDetailsController>();

    return Obx(
      () => AppAsyncBuilder<EmiScheduleModel>(
        isLoading: controller.isLoading.value,
        error: controller.error.value,
        isEmpty: controller.schedule.isEmpty,
        hasData: controller.schedule.isNotEmpty,
        onRetry: controller.load,
        emptyState: const AppEmptyState(
          title: 'No schedule',
          message: 'This loan has no instalments recorded.',
          icon: Icons.event_busy_outlined,
        ),
        builder: (BuildContext context) => AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Repayment schedule',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              AppSpacing.gapMd,
              for (final EmiScheduleModel emi in controller.schedule)
                _ScheduleRow(emi: emi),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.emi});

  final EmiScheduleModel emi;

  @override
  Widget build(BuildContext context) {
    final Color? tone = emi.isOverdue
        ? AppColors.danger
        : emi.isPaid
        ? AppColors.success
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 70,
            child: Text(
              emi.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              emi.formattedDueDate,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              MoneyUtil.format(emi.principalAmount),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              MoneyUtil.format(emi.interestAmount),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              emi.formattedEmi,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              emi.status.label,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 140,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
