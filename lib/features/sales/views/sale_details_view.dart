import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dialog.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/sales/controllers/sale_controller.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_item_model.dart';
import 'package:bike_showroom_management_system/features/sales/models/sale_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One sale, with its lines, totals and the actions still open on it.
class SaleDetailsView extends GetView<SaleDetailsController> {
  const SaleDetailsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Obx(() => Text(controller.detail.value.saleNumber)),
      actions: <Widget>[
        Obx(
          () => controller.detail.value.canCancel
              ? AppPermissionView(
                  permission: AppPermissions.salesCancel,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    child: AppButton.danger(
                      label: 'Cancel sale',
                      size: AppButtonSize.small,
                      onPressed: () => _confirmCancel(context),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 900,
          padding: EdgeInsets.zero,
          child: Obx(() {
            final SaleModel sale = controller.detail.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(sale: sale),
                AppSpacing.gapXl,
                _Items(sale: sale),
                AppSpacing.gapXl,
                _Totals(sale: sale),
                if (sale.isCancelled) ...<Widget>[
                  AppSpacing.gapXl,
                  _CancellationNotice(sale: sale),
                ],
              ],
            );
          }),
        ),
      ),
    ),
  );

  Future<void> _confirmCancel(BuildContext context) async {
    final String? reason = await AppDialog.confirmWithReason(
      title: 'Cancel this sale?',
      message:
          'The vehicle returns to stock, the invoice is voided and the '
          'accounting entries are reversed. The sale itself is kept, marked '
          'cancelled.',
      confirmLabel: 'Cancel sale',
    );
    if (reason != null) {
      await controller.cancel(reason);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sale});

  final SaleModel sale;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                sale.customerName ?? 'Unknown customer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: sale.status.value),
          ],
        ),
        AppSpacing.gapSm,
        _Detail(label: 'Phone', value: sale.customerPhone ?? '-'),
        _Detail(label: 'Sale date', value: sale.formattedDate),
        _Detail(label: 'Type', value: sale.saleType.label),
        _Detail(label: 'Salesperson', value: sale.salespersonName ?? '-'),
        if (sale.invoiceNumber != null)
          _Detail(label: 'Invoice', value: sale.invoiceNumber!),
        if (sale.notes != null && sale.notes!.isNotEmpty)
          _Detail(label: 'Notes', value: sale.notes!),
      ],
    ),
  );
}

class _Items extends StatelessWidget {
  const _Items({required this.sale});

  final SaleModel sale;

  @override
  Widget build(BuildContext context) {
    if (sale.items.isEmpty) {
      return AppCard(
        child: Text(
          'Loading line items...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Items', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapMd,
          for (final SaleItemModel item in sale.items)
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
                        if (item.stockCode != null)
                          Text(
                            '${item.stockCode} - ${item.chassisNumber ?? ""}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          '${item.quantity.toStringAsFixed(0)} x '
                          '${item.formattedUnitPrice}'
                          '${item.discount > 0 ? " less ${MoneyUtil.format(item.discount)}" : ""}'
                          ' + ${item.taxRate.toStringAsFixed(0)}% tax',
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
  const _Totals({required this.sale});

  final SaleModel sale;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: <Widget>[
        _Amount(label: 'Subtotal', value: sale.subtotal),
        _Amount(label: 'Discount', value: -sale.discount),
        _Amount(label: 'Tax', value: sale.taxAmount),
        if (sale.otherCharges > 0)
          _Amount(label: 'Other charges', value: sale.otherCharges),
        const Divider(height: AppSpacing.xxl),
        _Amount(label: 'Total', value: sale.totalAmount, isBold: true),
        _Amount(label: 'Paid', value: sale.paidAmount),
        _Amount(
          label: 'Outstanding',
          value: sale.outstandingAmount,
          isBold: true,
          highlight: sale.outstandingAmount > 0.01,
        ),
      ],
    ),
  );
}

class _CancellationNotice extends StatelessWidget {
  const _CancellationNotice({required this.sale});

  final SaleModel sale;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.block, color: AppColors.danger, size: 18),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Cancelled',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.danger),
              ),
              if (sale.cancellationReason != null)
                Text(
                  sale.cancellationReason!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    ),
  );
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
          width: 120,
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
