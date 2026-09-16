import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/expenses/controllers/expense_controller.dart';
import 'package:bike_showroom_management_system/features/expenses/models/expense_category_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Record an overhead. It posts to the ledger only once approved.
class ExpenseFormView extends GetView<ExpenseFormController> {
  const ExpenseFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Record Expense')),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 760,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<ExpenseCategoryModel>(
                        label: 'Category',
                        hint: controller.isLoadingCategories.value
                            ? 'Loading...'
                            : 'Select a category',
                        items: controller.categories.toList(),
                        itemLabel: (ExpenseCategoryModel c) => c.name,
                        value: controller.categories.firstWhereOrNull(
                          (ExpenseCategoryModel c) =>
                              c.id == controller.categoryId.value,
                        ),
                        isRequired: true,
                        onChanged: (ExpenseCategoryModel? c) =>
                            controller.categoryId.value = c?.id,
                      ),
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Expense date',
                        value: controller.expenseDate.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? d) =>
                            controller.expenseDate.value = d,
                      ),
                    ),
                  ],
                ),
                const _CategoryAccountNote(),

                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.money(
                      label: 'Amount',
                      controller: controller.amountController,
                      validator: controller.validateAmount,
                      helper: 'Net of tax',
                      onChanged: (_) => controller.categoryId.refresh(),
                    ),
                    AppTextField.money(
                      label: 'Tax',
                      controller: controller.taxAmountController,
                      validator: controller.validateTaxAmount,
                      isRequired: false,
                      onChanged: (_) => controller.categoryId.refresh(),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<PaymentMethod>(
                        label: 'Paid by',
                        items: PaymentMethod.values,
                        itemLabel: (PaymentMethod m) => m.label,
                        value: controller.paymentMethod.value,
                        isRequired: true,
                        onChanged: (PaymentMethod? m) {
                          if (m != null) {
                            controller.paymentMethod.value = m;
                          }
                        },
                      ),
                    ),
                    Obx(
                      () => AppTextField(
                        label: 'Reference',
                        controller: controller.referenceController,
                        validator: controller.validateReference,
                        isRequired: controller.requiresReference,
                        hint: 'Cheque / UPI / approval code',
                      ),
                    ),
                    AppTextField(
                      label: 'Vendor',
                      controller: controller.vendorController,
                      hint: 'Who was paid',
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Description',
                  controller: controller.descriptionController,
                  maxLines: 2,
                ),

                AppSpacing.gapLg,
                const _TotalPreview(),

                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: 'Record expense',
                        isLoading: controller.isSubmitting.value,
                        onPressed: () async {
                          final String? id = await controller.submit();
                          if (id != null) {
                            Get.back<String>(result: id);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Warns when the chosen category has no account code.
///
/// Without one the expense records but cannot post to a specific expense
/// account — the kind of thing that otherwise only surfaces at month end.
class _CategoryAccountNote extends StatelessWidget {
  const _CategoryAccountNote();

  @override
  Widget build(BuildContext context) {
    final ExpenseFormController controller = Get.find<ExpenseFormController>();
    return Obx(() {
      controller.categoryId.value;
      final ExpenseCategoryModel? category = controller.selectedCategory;
      if (category == null || category.isPostable) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.warning_amber_outlined,
              size: 18,
              color: AppColors.warning,
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                '${category.name} has no account code, so this expense cannot '
                'be posted to a specific expense account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TotalPreview extends StatelessWidget {
  const _TotalPreview();

  @override
  Widget build(BuildContext context) {
    final ExpenseFormController controller = Get.find<ExpenseFormController>();
    return Obx(() {
      controller.categoryId.value;
      return AppCard(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Total',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              MoneyUtil.format(controller.total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    });
  }
}
