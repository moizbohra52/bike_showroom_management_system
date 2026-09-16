import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/accounting/controllers/accounting_controller.dart';
import 'package:bike_showroom_management_system/features/accounting/models/account_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The branch's chart of accounts.
///
/// The codes are identical at every showroom — `provision_showroom_accounts`
/// seeds the same chart on creation — which is what lets branch figures be
/// added together in a group report.
class ChartOfAccountsView extends GetView<AccountingController> {
  const ChartOfAccountsView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Chart of Accounts',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppButton.ghost(
          label: 'Trial balance',
          icon: Icons.balance_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.trialBalance),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: AppButton.ghost(
          label: 'Journal',
          icon: Icons.menu_book_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.journal),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 260,
            child: Obx(
              () => AppDropdown<AccountType>(
                label: 'Account type',
                hint: 'All types',
                items: AccountType.values,
                itemLabel: (AccountType t) => t.label,
                value: controller.typeFilter.value,
                onChanged: controller.filterByType,
              ),
            ),
          ),
          AppSpacing.gapLg,
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<AccountModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.visibleAccounts.isEmpty,
                hasData: controller.visibleAccounts.isNotEmpty,
                onRetry: controller.load,
                emptyState: const AppEmptyState(
                  title: 'No accounts',
                  message:
                      'A showroom is provisioned with its chart of accounts '
                      'when it is created.',
                  icon: Icons.account_tree_outlined,
                ),
                builder: (BuildContext context) => ListView.builder(
                  itemCount: controller.visibleAccounts.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _AccountRow(account: controller.visibleAccounts[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final AccountModel account;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              account.accountCode,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(account.accountName),
                Text(
                  account.accountType.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (account.isSystemAccount)
            Tooltip(
              // Referenced by code inside the transaction functions; renaming
              // or retiring one would break a posting.
              message: 'Used by the transaction functions',
              child: Icon(
                Icons.lock_outline,
                size: 16,
                color: Theme.of(context).hintColor,
              ),
            ),
          if (!account.isActive)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(
                'Inactive',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ),
  );
}
