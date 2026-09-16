import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_date_picker.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/billing/models/invoice_model.dart';
import 'package:bike_showroom_management_system/features/payments/controllers/payment_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Record a receipt against an invoice.
class PaymentFormView extends GetView<PaymentFormController> {
  const PaymentFormView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Record Payment')),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 720,
          padding: EdgeInsets.zero,
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Obx(
                  () => AppDropdown<InvoiceModel>(
                    label: 'Invoice',
                    hint: controller.isLoadingInvoices.value
                        ? 'Loading...'
                        : 'Select an unpaid invoice',
                    items: controller.openInvoices.toList(),
                    itemLabel: (InvoiceModel i) =>
                        '${i.invoiceNumber} - ${i.customerName ?? ""} '
                        '(${i.formattedOutstanding} due)',
                    value: controller.openInvoices.firstWhereOrNull(
                      (InvoiceModel i) => i.id == controller.invoiceId.value,
                    ),
                    isRequired: true,
                    onChanged: (InvoiceModel? i) =>
                        controller.selectInvoice(i?.id),
                  ),
                ),
                AppSpacing.gapLg,
                const _SelectedInvoiceSummary(),

                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    AppTextField.money(
                      label: 'Amount',
                      controller: controller.amountController,
                      validator: controller.validateAmount,
                    ),
                    Obx(
                      () => AppDatePicker(
                        label: 'Payment date',
                        value: controller.paymentDate.value,
                        lastDate: DateTime.now(),
                        onChanged: (DateTime? d) =>
                            controller.paymentDate.value = d,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppFieldRow(
                  children: <Widget>[
                    Obx(
                      () => AppDropdown<PaymentMethod>(
                        label: 'Method',
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
                        label: 'Reference number',
                        controller: controller.referenceController,
                        validator: controller.validateReference,
                        // Mandatory for any non-cash tender: the server
                        // refuses one without it, since it could never be
                        // reconciled against a bank statement.
                        isRequired: controller.requiresReference,
                        hint: 'Cheque / UPI / approval code',
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,
                AppTextField.multiline(
                  label: 'Notes',
                  controller: controller.notesController,
                  maxLines: 2,
                ),

                AppSpacing.gapXxl,
                Row(
                  children: <Widget>[
                    AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
                    const Spacer(),
                    Obx(
                      () => AppButton.primary(
                        label: 'Record payment',
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

/// The balance the selected invoice still carries, so the amount can be
/// checked against it without leaving the form.
class _SelectedInvoiceSummary extends StatelessWidget {
  const _SelectedInvoiceSummary();

  @override
  Widget build(BuildContext context) {
    final PaymentFormController controller = Get.find<PaymentFormController>();
    return Obx(() {
      // Depend on the selection so this rebuilds when the invoice changes.
      controller.invoiceId.value;
      final InvoiceModel? invoice = controller.selectedInvoice;
      if (invoice == null) {
        return const SizedBox.shrink();
      }
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              invoice.customerName ?? 'Unknown customer',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            AppSpacing.gapXs,
            Text(
              'Invoice total ${invoice.formattedTotal} - '
              'paid ${invoice.formattedPaid} - '
              'outstanding ${invoice.formattedOutstanding}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    });
  }
}
