import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/features/purchases/controllers/purchase_controller.dart';
import 'package:bike_showroom_management_system/features/purchases/models/supplier_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Raise a purchase order.
///
/// No stock is created here — the order records what was bought and posts the
/// payable. Machines appear only when the consignment is received, which is a
/// separate step on the details screen because the chassis numbers are not
/// known until the lorry arrives.
class PurchaseCreateView extends GetView<PurchaseCreateController> {
  const PurchaseCreateView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Purchase')),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 880,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SectionTitle('Supplier'),
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<SupplierModel>(
                        label: 'Supplier',
                        hint: controller.isLoadingOptions.value
                            ? 'Loading...'
                            : 'Select a supplier',
                        items: controller.suppliers.toList(),
                        itemLabel: (SupplierModel s) => s.name,
                        value: controller.suppliers.firstWhereOrNull(
                          (SupplierModel s) =>
                              s.id == controller.supplierId.value,
                        ),
                        isRequired: true,
                        onChanged: (SupplierModel? s) =>
                            controller.supplierId.value = s?.id,
                      ),
                    ),
                    AppTextField(
                      label: 'Supplier invoice no.',
                      controller: controller.supplierInvoiceController,
                      hint: 'From their bill',
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Purchase date',
                        value: controller.purchaseDate.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? d) =>
                            controller.purchaseDate.value = d,
                      ),
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                const _Lines(),

                AppSpacing.gapXxl,
                _SectionTitle('Charges'),
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.money(
                      label: 'Discount',
                      controller: controller.discountController,
                      validator: controller.validateDiscount,
                      isRequired: false,
                      onChanged: (_) => controller.lines.refresh(),
                    ),
                    AppTextField.money(
                      label: 'Freight and other charges',
                      controller: controller.otherChargesController,
                      isRequired: false,
                      onChanged: (_) => controller.lines.refresh(),
                    ),
                  ],
                ),

                AppSpacing.gapXxl,
                const _Totals(),

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

class _Lines extends StatelessWidget {
  const _Lines();

  @override
  Widget build(BuildContext context) {
    final PurchaseCreateController controller =
        Get.find<PurchaseCreateController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Products', style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapLg,
        Obx(
          () => AppDropdown<ProductModel>(
            label: 'Add a product',
            hint: controller.selectableProducts.isEmpty
                ? 'Every catalogue product is already on this order'
                : 'Select a model',
            items: controller.selectableProducts,
            itemLabel: (ProductModel p) => p.displayName,
            // An action, not a bound value: the choice becomes a line below.
            value: null,
            isEnabled: controller.selectableProducts.isNotEmpty,
            onChanged: (ProductModel? product) {
              if (product != null) {
                controller.addLine(product);
              }
            },
          ),
        ),
        AppSpacing.gapLg,
        Obx(
          () => controller.lines.isEmpty
              ? Text(
                  'No products added yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Column(
                  children: <Widget>[
                    for (final PurchaseLineDraft line in controller.lines)
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

  final PurchaseLineDraft line;

  @override
  Widget build(BuildContext context) {
    final PurchaseCreateController controller =
        Get.find<PurchaseCreateController>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  line.product.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
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
              AppTextField.integer(
                label: 'Quantity',
                initialValue: line.quantity.toString(),
                isRequired: false,
                helper: 'One machine per unit on receipt',
                onChanged: (String value) => controller.updateLine(
                  line,
                  quantity: int.tryParse(value.trim()) ?? 0,
                ),
              ),
              AppTextField.money(
                label: 'Unit cost',
                initialValue: line.unitCost.toStringAsFixed(2),
                isRequired: false,
                onChanged: (String value) => controller.updateLine(
                  line,
                  unitCost: double.tryParse(value.trim()) ?? 0,
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
              'Line total ${MoneyUtil.format(line.amounts.totalValue)}',
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
    final PurchaseCreateController controller =
        Get.find<PurchaseCreateController>();

    return Obx(() {
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
            _TotalRow(label: 'Payable', value: totals.totalValue, isBold: true),
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

class _SubmitBar extends StatelessWidget {
  const _SubmitBar();

  @override
  Widget build(BuildContext context) {
    final PurchaseCreateController controller =
        Get.find<PurchaseCreateController>();

    return Obx(() {
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
                label: 'Raise order',
                size: AppButtonSize.large,
                isLoading: controller.isSubmitting.value,
                onPressed: () async {
                  final String? id = await controller.submit();
                  if (id != null) {
                    Get.back<String>(result: id);
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
