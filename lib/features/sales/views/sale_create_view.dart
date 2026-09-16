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
import 'package:bike_showroom_management_system/features/customers/models/customer_model.dart';
import 'package:bike_showroom_management_system/features/finance/models/finance_company_model.dart';
import 'package:bike_showroom_management_system/features/inventory/models/inventory_model.dart';
import 'package:bike_showroom_management_system/features/sales/controllers/sale_create_controller.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Assemble and book a sale.
///
/// Everything shown here is a preview: `create_sale_transaction` recomputes
/// every figure from the catalogue when the form is submitted. The totals
/// exist so the salesperson can quote a number, not so the client can decide
/// one.
class SaleCreateView extends GetView<SaleCreateController> {
  const SaleCreateView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Sale')),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 900,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SectionTitle('Customer'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<CustomerModel>(
                        label: 'Customer',
                        hint: controller.isLoadingOptions.value
                            ? 'Loading...'
                            : 'Select a customer',
                        items: controller.customers.toList(),
                        itemLabel: (CustomerModel c) =>
                            '${c.name} (${c.phone})',
                        value: controller.customers.firstWhereOrNull(
                          (CustomerModel c) =>
                              c.id == controller.customerId.value,
                        ),
                        isRequired: true,
                        onChanged: (CustomerModel? c) =>
                            controller.customerId.value = c?.id,
                      ),
                    ),
                    Obx(
                      () => AppDropdown<SaleType>(
                        label: 'Sale type',
                        items: SaleType.values,
                        itemLabel: (SaleType t) => t.label,
                        value: controller.saleType.value,
                        isRequired: true,
                        onChanged: (SaleType? t) {
                          if (t != null) {
                            controller.saleType.value = t;
                            controller.recalculateEmi();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDatePicker(
                        label: 'Sale date',
                        value: controller.saleDate.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? d) =>
                            controller.saleDate.value = d,
                      ),
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Delivery date',
                        value: controller.deliveryDate.value,
                        onChanged: (DateTime? d) =>
                            controller.deliveryDate.value = d,
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                const _VehicleLines(),

                AppSpacing.gapXxl,
                _SectionTitle('Charges'),
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.money(
                      label: 'Additional discount',
                      controller: controller.discountController,
                      validator: controller.validateDiscount,
                      isRequired: false,
                      onChanged: (_) => controller.lines.refresh(),
                    ),
                    AppTextField.money(
                      label: 'Other charges',
                      controller: controller.otherChargesController,
                      isRequired: false,
                      helper: 'Registration, insurance, accessories',
                      onChanged: (_) => controller.lines.refresh(),
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                const _Totals(),

                AppSpacing.gapXxl,
                _SectionTitle('Payment received now'),
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.money(
                      label: 'Amount received',
                      controller: controller.paidAmountController,
                      validator: controller.validatePaidAmount,
                      isRequired: false,
                      onChanged: (_) => controller.lines.refresh(),
                    ),
                    Obx(
                      () => AppDropdown<PaymentMethod>(
                        label: 'Method',
                        items: PaymentMethod.values,
                        itemLabel: (PaymentMethod m) => m.label,
                        value: controller.paymentMethod.value,
                        onChanged: (PaymentMethod? m) {
                          if (m != null) {
                            controller.paymentMethod.value = m;
                          }
                        },
                      ),
                    ),
                    AppTextField(
                      label: 'Reference',
                      controller: controller.paymentReferenceController,
                      hint: 'Cheque / UPI / card reference',
                    ),
                  ],
                ),

                Obx(
                  () => controller.isFinanced
                      ? const _FinanceSection()
                      : const SizedBox.shrink(),
                ),

                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Notes',
                  controller: controller.notesController,
                  maxLines: 2,
                ),

                AppSpacing.gapXxl,
                const _SubmitBar(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The vehicles on this sale, and the picker that adds one.
class _VehicleLines extends StatelessWidget {
  const _VehicleLines();

  @override
  Widget build(BuildContext context) {
    final SaleCreateController controller = Get.find<SaleCreateController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Vehicles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        AppSpacing.gapLg,
        Obx(
          () => AppDropdown<InventoryModel>(
            label: 'Add a vehicle from stock',
            hint: controller.selectableUnits.isEmpty
                ? 'No allocatable stock at this showroom'
                : 'Select a unit',
            items: controller.selectableUnits,
            itemLabel: (InventoryModel u) =>
                '${u.stockCode} - ${u.displayName}',
            // Always null: this dropdown is an action, not a bound value. The
            // chosen unit becomes a line below and leaves the picker empty for
            // the next one.
            value: null,
            isEnabled: controller.selectableUnits.isNotEmpty,
            onChanged: (InventoryModel? unit) {
              if (unit != null) {
                controller.addLine(unit);
              }
            },
          ),
        ),
        AppSpacing.gapLg,
        Obx(
          () => controller.lines.isEmpty
              ? Text(
                  'No vehicles added yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Column(
                  children: <Widget>[
                    for (final SaleLineDraft line in controller.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _LineCard(line: line),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line});

  final SaleLineDraft line;

  @override
  Widget build(BuildContext context) {
    final SaleCreateController controller = Get.find<SaleCreateController>();
    final LineAmounts amounts = line.amounts;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      line.unit.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${line.unit.stockCode} - ${line.unit.chassisNumber}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Remove',
                isDestructive: true,
                onPressed: () => controller.removeLine(line),
              ),
            ],
          ),
          AppSpacing.gapMd,
          AppFieldRow(
            children: <Widget>[
              AppTextField.money(
                label: 'Unit price',
                initialValue: line.unitPrice.toStringAsFixed(2),
                isRequired: false,
                onChanged: (String value) => controller.updateLine(
                  line,
                  unitPrice: double.tryParse(value.trim()) ?? 0,
                ),
              ),
              AppTextField.money(
                label: 'Discount',
                initialValue: line.discount.toStringAsFixed(2),
                isRequired: false,
                onChanged: (String value) => controller.updateLine(
                  line,
                  discount: double.tryParse(value.trim()) ?? 0,
                ),
              ),
              AppTextField.money(
                label: 'Tax %',
                initialValue: line.taxRate.toStringAsFixed(2),
                isRequired: false,
                isReadOnly: true,
                helper: 'From the catalogue',
              ),
            ],
          ),
          AppSpacing.gapMd,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Line total ${MoneyUtil.format(amounts.totalValue)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals();

  @override
  Widget build(BuildContext context) {
    final SaleCreateController controller = Get.find<SaleCreateController>();

    return Obx(() {
      // Touch the observable so this rebuilds whenever a line or a charge
      // field changes; the totals are derived, not stored.
      final int lineCount = controller.lines.length;
      final DocumentAmounts totals = controller.totals;

      return AppCard(
        child: Column(
          children: <Widget>[
            _TotalRow(
              label: 'Subtotal ($lineCount)',
              value: totals.subtotalValue,
            ),
            _TotalRow(label: 'Discount', value: -totals.discountValue),
            _TotalRow(label: 'Tax', value: totals.taxValue),
            if (totals.otherChargesValue > 0)
              _TotalRow(
                label: 'Other charges',
                value: totals.otherChargesValue,
              ),
            const Divider(height: AppSpacing.xxl),
            _TotalRow(label: 'Total', value: totals.totalValue, isBold: true),
            _TotalRow(label: 'Received now', value: controller.paidAmount),
            _TotalRow(
              label: 'Outstanding',
              value: controller.outstanding,
              isBold: true,
            ),
            if (controller.discountPercentage > 0) ...<Widget>[
              AppSpacing.gapSm,
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Discount is '
                  '${controller.discountPercentage.toStringAsFixed(2)}% of the '
                  'subtotal. Above the showroom limit this needs approval.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = isBold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(MoneyUtil.format(value), style: style),
        ],
      ),
    );
  }
}

/// Loan terms, shown only for a financed sale.
class _FinanceSection extends StatelessWidget {
  const _FinanceSection();

  @override
  Widget build(BuildContext context) {
    final SaleCreateController controller = Get.find<SaleCreateController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSpacing.gapXxl,
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Text(
            'Finance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        AppFieldRow(
          children: <Widget>[
            Obx(
              () => AppDropdown<FinanceCompanyModel>(
                label: 'Finance company',
                hint: 'Select a financier',
                items: controller.financeCompanies.toList(),
                itemLabel: (FinanceCompanyModel f) => f.name,
                value: controller.financeCompanies.firstWhereOrNull(
                  (FinanceCompanyModel f) =>
                      f.id == controller.financeCompanyId.value,
                ),
                isRequired: true,
                onChanged: (FinanceCompanyModel? f) =>
                    controller.financeCompanyId.value = f?.id,
              ),
            ),
            AppTextField.money(
              label: 'Down payment',
              controller: controller.downPaymentController,
              isRequired: false,
              onChanged: (_) => controller.recalculateEmi(),
            ),
          ],
        ),
        AppSpacing.gapLg,
        AppFieldRow(
          children: <Widget>[
            AppTextField.money(
              label: 'Interest rate (% p.a.)',
              controller: controller.interestRateController,
              validator: controller.validateInterestRate,
              isRequired: false,
              onChanged: (_) => controller.recalculateEmi(),
            ),
            AppTextField.integer(
              label: 'Tenure (months)',
              controller: controller.tenureController,
              validator: controller.validateTenure,
              isRequired: false,
              onChanged: (_) => controller.recalculateEmi(),
            ),
            Obx(
              () => AppDropdown<InterestType>(
                label: 'Interest type',
                items: InterestType.values,
                itemLabel: (InterestType t) => t.label,
                value: controller.interestType.value,
                onChanged: (InterestType? t) {
                  if (t != null) {
                    controller.interestType.value = t;
                    controller.recalculateEmi();
                  }
                },
              ),
            ),
            AppTextField.money(
              label: 'Processing fee',
              controller: controller.processingFeeController,
              isRequired: false,
            ),
          ],
        ),
        AppSpacing.gapLg,
        Obx(
          () => AppCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Financed amount '
                        '${MoneyUtil.format(controller.financedAmount)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      AppSpacing.gapXs,
                      Text(
                        // The figure comes from the database's own
                        // calculate_emi, so the quote cannot drift from the
                        // schedule that will be generated.
                        'Calculated by the server, not estimated here.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (controller.isCalculatingEmi.value)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '${MoneyUtil.format(controller.emiPreview.value)} / month',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar();

  @override
  Widget build(BuildContext context) {
    final SaleCreateController controller = Get.find<SaleCreateController>();

    return Obx(() {
      // Depend on the lines so the blocking message re-evaluates as the form
      // is filled in.
      controller.lines.length;
      final String? issue = controller.blockingIssue;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (issue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      issue,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
              const Spacer(),
              AppButton.primary(
                label: 'Book sale',
                size: AppButtonSize.large,
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  final SaleTransactionResult? result = await controller
                      .submit();
                  if (result != null) {
                    Get.back<SaleTransactionResult>(result: result);
                  }
                },
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
