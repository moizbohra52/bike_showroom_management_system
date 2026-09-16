import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/accounting/controllers/accounting_controller.dart';
import 'package:bike_showroom_management_system/features/accounting/models/account_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The trial balance: every account with activity, and the check that the
/// books balance.
///
/// Summed across all accounts, total debits must equal total credits. That is
/// not a report detail — it is the property the whole double-entry system
/// exists to maintain, and it is stated plainly at the top rather than left
/// for the reader to add up.
class TrialBalanceView extends GetView<AccountingController> {
  const TrialBalanceView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Trial Balance',
    body: AppContentContainer(
      child: Obx(
        () => AppAsyncBuilder<TrialBalanceRow>(
          isLoading: controller.isLoading.value,
          error: controller.error.value,
          isEmpty: controller.activeTrialBalance.isEmpty,
          hasData: controller.activeTrialBalance.isNotEmpty,
          onRetry: controller.load,
          emptyState: const AppEmptyState(
            title: 'Nothing posted yet',
            message:
                'Accounts appear here once a sale, purchase, payment or '
                'expense has posted to them.',
            icon: Icons.balance_outlined,
          ),
          builder: (BuildContext context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _BalanceBanner(),
              AppSpacing.gapLg,
              const _HeaderRow(),
              Expanded(
                child: ListView.builder(
                  itemCount: controller.activeTrialBalance.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _Row(row: controller.activeTrialBalance[index]),
                ),
              ),
              const _TotalsRow(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BalanceBanner extends StatelessWidget {
  const _BalanceBanner();

  @override
  Widget build(BuildContext context) {
    final AccountingController controller = Get.find<AccountingController>();
    return Obx(() {
      final bool balanced = controller.isBalanced;
      return AppCard(
        child: Row(
          children: <Widget>[
            Icon(
              balanced ? Icons.check_circle_outline : Icons.error_outline,
              color: balanced ? AppColors.success : AppColors.danger,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                balanced
                    ? 'The books balance: debits equal credits.'
                    : 'The books do not balance. This should be impossible — '
                          'every posting is checked by a database trigger — so '
                          'report it rather than working around it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text('Account', style: style)),
          SizedBox(
            width: 130,
            child: Text('Debit', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: 130,
            child: Text('Credit', textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: 130,
            child: Text('Balance', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final TrialBalanceRow row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(row.label),
                Text(
                  row.accountType.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              MoneyUtil.format(row.totalDebit),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              MoneyUtil.format(row.totalCredit),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              MoneyUtil.format(row.balance),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow();

  @override
  Widget build(BuildContext context) {
    final AccountingController controller = Get.find<AccountingController>();
    return Obx(
      () => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: AppCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  MoneyUtil.format(controller.totalDebit),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  MoneyUtil.format(controller.totalCredit),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 130),
            ],
          ),
        ),
      ),
    );
  }
}
