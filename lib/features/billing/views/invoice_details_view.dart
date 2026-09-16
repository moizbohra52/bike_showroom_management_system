import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/billing/controllers/invoice_controller.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_item_model.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A tax invoice, laid out the way it prints.
///
/// Rendering to PDF arrives in Phase 9; this is the same content on screen, so
/// the figures and the GST breakdown can be checked before that exists.
class InvoiceDetailsView extends GetView<InvoiceDetailsController> {
  const InvoiceDetailsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Obx(() => Text(controller.detail.value.invoiceNumber)),
      actions: <Widget>[
        Obx(
          () => controller.detail.value.acceptsPayment
              ? AppPermissionView(
                  permission: AppPermissions.paymentsCreate,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    child: AppButton.primary(
                      label: 'Record payment',
                      icon: Icons.payments_outlined,
                      size: AppButtonSize.small,
                      onPressed: () => _recordPayment(),
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
          maxWidth: 860,
          padding: EdgeInsets.zero,
          child: Obx(() {
            final InvoiceModel invoice = controller.detail.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(invoice: invoice),
                AppSpacing.gapXl,
                _Lines(invoice: invoice),
                AppSpacing.gapXl,
                _Totals(invoice: invoice),
              ],
            );
          }),
        ),
      ),
    ),
  );

  Future<void> _recordPayment() async {
    final Object? result = await Get.toNamed(
      AppRoutes.paymentForm,
      arguments: controller.detail.value,
    );
    if (result is String) {
      await controller.load();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice});

  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Tax Invoice',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: invoice.status.value),
          ],
        ),
        AppSpacing.gapMd,
        _Detail(label: 'Invoice no.', value: invoice.invoiceNumber),
        _Detail(label: 'Date', value: invoice.formattedDate),
        if (invoice.saleNumber != null)
          _Detail(label: 'Against sale', value: invoice.saleNumber!),
        const Divider(height: AppSpacing.xxl),
        Text('Billed to', style: Theme.of(context).textTheme.titleSmall),
        AppSpacing.gapSm,
        _Detail(label: 'Name', value: invoice.customerName ?? '-'),
        _Detail(label: 'Phone', value: invoice.customerPhone ?? '-'),
        if (invoice.customerAddress != null)
          _Detail(label: 'Address', value: invoice.customerAddress!),
        if (invoice.customerGstNumber != null)
          _Detail(label: 'GSTIN', value: invoice.customerGstNumber!),
        if (invoice.dueDate != null)
          _Detail(label: 'Due date', value: DateUtil.format(invoice.dueDate)),
      ],
    ),
  );
}

class _Lines extends StatelessWidget {
  const _Lines({required this.invoice});

  final InvoiceModel invoice;

  /// The per-line detail a GST invoice must show: HSN, quantity and rate, the
  /// taxable value after discount, and the tax charged on it.
  static String _lineSummary(InvoiceItemModel line) {
    final String quantity =
        '${line.quantity.toStringAsFixed(0)} x ${line.formattedUnitPrice}';
    final String tax =
        '${line.taxRate.toStringAsFixed(0)}% tax '
        '${MoneyUtil.format(line.taxAmount)}';
    return <String>[
      if (line.hsnCode != null) 'HSN ${line.hsnCode}',
      quantity,
      'Taxable ${line.formattedTaxable}',
      tax,
    ].join('  -  ');
  }

  @override
  Widget build(BuildContext context) {
    if (invoice.items.isEmpty) {
      return AppCard(
        child: Text(
          'Loading lines...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final List<InvoiceItemModel> lines =
        List<InvoiceItemModel>.of(invoice.items)..sort(
          (InvoiceItemModel a, InvoiceItemModel b) =>
              a.sortOrder.compareTo(b.sortOrder),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Items', style: Theme.of(context).textTheme.titleSmall),
          AppSpacing.gapMd,
          for (final InvoiceItemModel line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(line.description),
                        Text(
                          _lineSummary(line),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    line.formattedTotal,
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
  const _Totals({required this.invoice});

  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Amount(label: 'Taxable value', value: invoice.taxableValue),
        _Amount(label: 'Tax', value: invoice.taxAmount),
        if (invoice.otherCharges > 0)
          _Amount(label: 'Other charges', value: invoice.otherCharges),
        const Divider(height: AppSpacing.xxl),
        _Amount(label: 'Total', value: invoice.totalAmount, isBold: true),
        _Amount(label: 'Paid', value: invoice.paidAmount),
        _Amount(
          label: 'Outstanding',
          value: invoice.outstandingAmount,
          isBold: true,
          highlight: invoice.outstandingAmount > 0.01,
        ),
        AppSpacing.gapMd,
        // An Indian tax invoice prints the total in words.
        Text(
          'Rupees ${invoice.totalInWords}',
          style: Theme.of(context).textTheme.bodySmall,
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
