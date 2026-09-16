import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/accounting/controllers/accounting_controller.dart';
import 'package:bike_showroom_management_system/features/accounting/models/journal_entry_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The journal: every posting, with its lines, newest first.
///
/// Read-only by construction. Each entry was written by a transaction
/// function — a sale, a purchase, a payment, an expense — so there is nothing
/// here for a person to author, and a journal the client could post to would
/// be a way to record figures no source document supports.
class JournalView extends GetView<JournalController> {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Journal',
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
              () => AppAsyncBuilder<JournalEntryModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'Nothing posted yet',
                        message:
                            'Entries appear here as sales, purchases, '
                            'payments and expenses are recorded.',
                        icon: Icons.menu_book_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: ListView.builder(
                        itemCount: controller.response.value.items.length,
                        itemBuilder: (BuildContext context, int index) =>
                            _EntryCard(
                              entry: controller.response.value.items[index],
                            ),
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
    final JournalController controller = Get.find<JournalController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 300,
          child: AppSearchField(
            hint: 'Search the description',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 240,
          child: Obx(
            () => AppDropdown<AccountingReferenceType>(
              label: 'Source',
              hint: 'All',
              items: AccountingReferenceType.values,
              itemLabel: (AccountingReferenceType t) => t.label,
              value: controller.referenceFilter.value,
              onChanged: controller.filterByReference,
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: AppDateRangeField(
            label: 'Posted between',
            value: controller.params.value.dateRange,
            onChanged: controller.filterByDateRange,
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntryModel entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                entry.formattedDate,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          AppSpacing.gapXs,
          Row(
            children: <Widget>[
              Text(
                entry.referenceType.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (entry.createdByName != null) ...<Widget>[
                Text(
                  '  -  by ${entry.createdByName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const Spacer(),
              if (entry.isReversal)
                Text(
                  'Reversal',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                )
              else if (entry.isReversed)
                Text(
                  'Reversed',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                ),
            ],
          ),
          AppSpacing.gapMd,
          for (final JournalLineModel line in entry.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: <Widget>[
                  // Credits are indented, the way a journal is written on
                  // paper, so the two sides are legible at a glance.
                  SizedBox(width: line.isDebit ? 0 : AppSpacing.xxl),
                  Expanded(
                    child: Text(
                      line.accountLabel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      line.isDebit ? MoneyUtil.format(line.debit) : '',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      line.isDebit ? '' : MoneyUtil.format(line.credit),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.isBalanced
                      ? 'Balanced'
                      : 'UNBALANCED - report this entry',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: entry.isBalanced ? null : AppColors.danger,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  MoneyUtil.format(entry.totalDebit),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  MoneyUtil.format(entry.totalCredit),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
