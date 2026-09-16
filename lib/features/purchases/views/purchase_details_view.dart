import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/purchases/controllers/purchase_controller.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_item_model.dart';
import 'package:bike_showroom_management_system/features/purchases/models/purchase_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One purchase order, and the step that takes its machines into stock.
class PurchaseDetailsView extends GetView<PurchaseDetailsController> {
  const PurchaseDetailsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Obx(() => Text(controller.detail.value.purchaseNumber)),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 900,
          padding: EdgeInsets.zero,
          child: Obx(() {
            final PurchaseModel purchase = controller.detail.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(purchase: purchase),
                AppSpacing.gapXl,
                _Lines(purchase: purchase),
                AppSpacing.gapXl,
                _Totals(purchase: purchase),
                if (purchase.canReceive) ...<Widget>[
                  AppSpacing.gapXl,
                  const _ReceiveSection(),
                ],
              ],
            );
          }),
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.purchase});

  final PurchaseModel purchase;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                purchase.supplierName ?? 'Unknown supplier',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: purchase.status.value),
          ],
        ),
        AppSpacing.gapMd,
        _Detail(label: 'Purchase date', value: purchase.formattedDate),
        if (purchase.supplierInvoiceNo != null)
          _Detail(
            label: 'Supplier invoice',
            value: purchase.supplierInvoiceNo!,
          ),
        if (purchase.supplierGstNumber != null)
          _Detail(label: 'Supplier GSTIN', value: purchase.supplierGstNumber!),
        if (purchase.receivedDate != null)
          _Detail(
            label: 'Received',
            value: DateUtil.format(purchase.receivedDate),
          ),
        if (purchase.notes != null && purchase.notes!.isNotEmpty)
          _Detail(label: 'Notes', value: purchase.notes!),
      ],
    ),
  );
}

class _Lines extends StatelessWidget {
  const _Lines({required this.purchase});

  final PurchaseModel purchase;

  @override
  Widget build(BuildContext context) {
    if (purchase.items.isEmpty) {
      return AppCard(
        child: Text(
          'Loading lines...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Ordered', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapMd,
          for (final PurchaseItemModel item in purchase.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.label),
                        Text(
                          '${item.quantity.toStringAsFixed(0)} x '
                          '${item.formattedUnitCost} + '
                          '${item.taxRate.toStringAsFixed(0)}% tax',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.formattedTotal,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.purchase});

  final PurchaseModel purchase;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: <Widget>[
        _Amount(label: 'Subtotal', value: purchase.subtotal),
        _Amount(label: 'Discount', value: -purchase.discount),
        _Amount(label: 'Tax', value: purchase.taxAmount),
        if (purchase.otherCharges > 0)
          _Amount(label: 'Other charges', value: purchase.otherCharges),
        const Divider(height: AppSpacing.xxl),
        _Amount(label: 'Payable', value: purchase.totalAmount, isBold: true),
        _Amount(label: 'Paid', value: purchase.paidAmount),
        _Amount(
          label: 'Outstanding',
          value: purchase.outstandingAmount,
          isBold: true,
          highlight: purchase.outstandingAmount > 0.01,
        ),
      ],
    ),
  );
}

/// One chassis/engine pair per expected machine.
///
/// All of them must be filled before receiving: `receive_purchase` marks the
/// whole order RECEIVED and refuses a second attempt, so a half-entered
/// consignment would leave machines with no way to be added later.
class _ReceiveSection extends StatelessWidget {
  const _ReceiveSection();

  @override
  Widget build(BuildContext context) {
    final PurchaseDetailsController controller =
        Get.find<PurchaseDetailsController>();

    return Obx(() {
      if (controller.units.isEmpty) {
        return const SizedBox.shrink();
      }
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Receive into stock',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${controller.completeUnitCount} of '
                  '${controller.units.length} identified',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            AppSpacing.gapXs,
            Text(
              'Each machine needs its own chassis and engine number. Chassis '
              'numbers exclude the letters I, O and Q.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppSpacing.gapLg,
            for (int i = 0; i < controller.units.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _UnitRow(index: i, unit: controller.units[i]),
              ),
            AppSpacing.gapMd,
            AppPermissionView(
              permission: AppPermissions.inventoryCreate,
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  AppButton.primary(
                    label: 'Receive ${controller.units.length} unit(s)',
                    isLoading: controller.isReceiving.value,
                    onPressed: controller.receive,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.index, required this.unit});

  final int index;
  final ReceivedUnitDraft unit;

  @override
  Widget build(BuildContext context) {
    final PurchaseDetailsController controller =
        Get.find<PurchaseDetailsController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${index + 1}. ${unit.productLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapXs,
        AppFieldRow(
          children: <Widget>[
            AppTextField.code(
              label: 'Chassis number',
              controller: unit.chassis,
              maxLength: 25,
              onChanged: (_) => controller.units.refresh(),
            ),
            AppTextField.code(
              label: 'Engine number',
              controller: unit.engine,
              maxLength: 25,
              onChanged: (_) => controller.units.refresh(),
            ),
          ],
        ),
      ],
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

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    this.isBold = false,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool isBold;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    TextStyle? style = isBold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    if (highlight) {
      style = style?.copyWith(color: AppColors.warning);
    }
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
