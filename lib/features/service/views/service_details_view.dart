import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/core/utils/date_util.dart';
import 'package:bike_showroom_management_system/core/utils/money_util.dart';
import 'package:bike_showroom_management_system/features/service/controllers/service_controller.dart';
import 'package:bike_showroom_management_system/features/service/models/service_item_model.dart';
import 'package:bike_showroom_management_system/features/service/models/service_record_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One job card: its details, its lines, and the step that completes it.
class ServiceDetailsView extends GetView<ServiceDetailsController> {
  const ServiceDetailsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Obx(() => Text(controller.detail.value.serviceNumber)),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: context.pagePadding,
        child: AppContentContainer(
          maxWidth: 900,
          padding: EdgeInsets.zero,
          child: Obx(() {
            final ServiceRecordModel service = controller.detail.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(service: service),
                AppSpacing.gapXl,
                _StatusBar(service: service),
                AppSpacing.gapXl,
                _Items(service: service),
                if (service.canEditItems) ...<Widget>[
                  AppSpacing.gapLg,
                  const _AddItemCard(),
                ],
                AppSpacing.gapXl,
                _Totals(service: service),
                if (service.canComplete) ...<Widget>[
                  AppSpacing.gapXl,
                  const _CompleteCard(),
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
  const _Header({required this.service});

  final ServiceRecordModel service;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                service.vehicleLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: service.serviceStatus.value),
          ],
        ),
        AppSpacing.gapMd,
        _Detail(label: 'Customer', value: service.customerName ?? '-'),
        _Detail(label: 'Phone', value: service.customerPhone ?? '-'),
        _Detail(label: 'Service date', value: service.formattedDate),
        _Detail(label: 'Type', value: service.serviceType.label),
        _Detail(label: 'Odometer', value: '${service.odometerReading} km'),
        if (service.serviceAdvisorName != null)
          _Detail(label: 'Advisor', value: service.serviceAdvisorName!),
        if (service.complaint != null && service.complaint!.isNotEmpty)
          _Detail(label: 'Complaint', value: service.complaint!),
        if (service.workDone != null && service.workDone!.isNotEmpty)
          _Detail(label: 'Work done', value: service.workDone!),
        if (service.nextServiceDate != null)
          _Detail(
            label: 'Next service',
            value:
                '${DateUtil.format(service.nextServiceDate)}'
                '${service.nextServiceKm != null ? " or ${service.nextServiceKm} km" : ""}',
          ),
      ],
    ),
  );
}

/// Moves the job card along the workshop board.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.service});

  final ServiceRecordModel service;

  /// Only the states a job card actually passes through while open.
  /// Completion is its own transaction, and cancellation its own decision.
  static const List<ServiceStatus> _workflow = <ServiceStatus>[
    ServiceStatus.booked,
    ServiceStatus.received,
    ServiceStatus.inProgress,
    ServiceStatus.waitingForParts,
  ];

  @override
  Widget build(BuildContext context) {
    if (!service.canComplete) {
      return const SizedBox.shrink();
    }
    final ServiceDetailsController controller =
        Get.find<ServiceDetailsController>();

    return AppPermissionView(
      permission: AppPermissions.serviceEdit,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Progress', style: Theme.of(context).textTheme.titleSmall),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final ServiceStatus status in _workflow)
                  ChoiceChip(
                    label: Text(status.label),
                    selected: service.serviceStatus == status,
                    onSelected: (bool selected) {
                      if (selected && service.serviceStatus != status) {
                        controller.setStatus(status);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.service});

  final ServiceRecordModel service;

  @override
  Widget build(BuildContext context) {
    final ServiceDetailsController controller =
        Get.find<ServiceDetailsController>();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Parts and labour',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          AppSpacing.gapMd,
          if (service.items.isEmpty)
            Text(
              'Nothing added yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final ServiceItemModel item in service.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.description),
                          Text(
                            '${item.itemType.label} - '
                            '${item.quantity.toStringAsFixed(0)} x '
                            '${item.formattedUnitPrice}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (!item.isChargeable)
                            Text(
                              // Recorded for costing, never billed — this is
                              // what warranty and free-service work looks like.
                              'Not charged to the customer',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.info),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      item.isChargeable ? item.formattedTotal : '-',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (service.canEditItems)
                      AppPermissionView(
                        permission: AppPermissions.serviceEdit,
                        child: AppIconButton(
                          icon: Icons.close,
                          tooltip: 'Remove',
                          isDestructive: true,
                          onPressed: () => controller.removeItem(item),
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Adds a part or a labour line.
class _AddItemCard extends StatefulWidget {
  const _AddItemCard();

  @override
  State<_AddItemCard> createState() => _AddItemCardState();
}

class _AddItemCardState extends State<_AddItemCard> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _unitPrice = TextEditingController();
  final TextEditingController _taxRate = TextEditingController(text: '18');
  ServiceItemType _type = ServiceItemType.part;
  bool _chargeable = true;

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final ServiceDetailsController controller =
        Get.find<ServiceDetailsController>();
    final bool added = await controller.addItem(
      itemType: _type,
      description: _description.text,
      quantity: double.tryParse(_quantity.text.trim()) ?? 1,
      unitPrice: double.tryParse(_unitPrice.text.trim()) ?? 0,
      taxRate: double.tryParse(_taxRate.text.trim()) ?? 0,
      isChargeable: _chargeable,
    );
    if (added) {
      _description.clear();
      _unitPrice.clear();
      setState(() => _quantity.text = '1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServiceDetailsController controller =
        Get.find<ServiceDetailsController>();

    return AppPermissionView(
      permission: AppPermissions.serviceEdit,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Add a line', style: Theme.of(context).textTheme.titleSmall),
            AppSpacing.gapMd,
            AppFieldRow(
              children: <Widget>[
                AppDropdown<ServiceItemType>(
                  label: 'Type',
                  items: ServiceItemType.values,
                  itemLabel: (ServiceItemType t) => t.label,
                  value: _type,
                  onChanged: (ServiceItemType? t) {
                    if (t != null) {
                      setState(() => _type = t);
                    }
                  },
                ),
                AppTextField(
                  label: 'Description',
                  controller: _description,
                  isRequired: true,
                  hint: 'Part name or work performed',
                ),
              ],
            ),
            AppSpacing.gapLg,
            AppFieldRow(
              children: <Widget>[
                AppTextField.integer(
                  label: 'Quantity',
                  controller: _quantity,
                  isRequired: false,
                ),
                AppTextField.money(
                  label: 'Unit price',
                  controller: _unitPrice,
                  isRequired: false,
                ),
                AppTextField.money(
                  label: 'Tax %',
                  controller: _taxRate,
                  isRequired: false,
                ),
              ],
            ),
            AppSpacing.gapMd,
            Row(
              children: <Widget>[
                Checkbox(
                  value: _chargeable,
                  onChanged: (bool? value) =>
                      setState(() => _chargeable = value ?? true),
                ),
                Expanded(
                  child: Text(
                    // The distinction that decides what reaches the invoice.
                    'Charge this to the customer. Clear it for work covered '
                    'by warranty or a free service — it is still recorded and '
                    'costed, just not billed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            AppSpacing.gapMd,
            Row(
              children: <Widget>[
                const Spacer(),
                Obx(
                  () => AppButton.secondary(
                    label: 'Add line',
                    icon: Icons.add,
                    isLoading: controller.isSaving.value,
                    onPressed: _add,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.service});

  final ServiceRecordModel service;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: <Widget>[
        if (!service.isCompleted) ...<Widget>[
          _Amount(
            label: 'Chargeable so far',
            value: service.chargeableSubtotal,
          ),
          if (service.absorbedValue > 0)
            _Amount(
              label: 'Absorbed (warranty / free)',
              value: service.absorbedValue,
            ),
          AppSpacing.gapSm,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              // The server recomputes all of this at completion, from the
              // rows themselves.
              'A preview. The final figures are computed when the job card is '
              'completed.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ] else ...<Widget>[
          _Amount(label: 'Subtotal', value: service.subtotal),
          _Amount(label: 'Discount', value: -service.discount),
          _Amount(label: 'Tax', value: service.taxAmount),
          const Divider(height: AppSpacing.xxl),
          _Amount(label: 'Total', value: service.totalAmount, isBold: true),
          _Amount(label: 'Paid', value: service.paidAmount),
          _Amount(
            label: 'Outstanding',
            value: service.outstandingAmount,
            isBold: true,
            highlight: service.outstandingAmount > 0.01,
          ),
        ],
      ],
    ),
  );
}

/// Completes the job card.
class _CompleteCard extends StatefulWidget {
  const _CompleteCard();

  @override
  State<_CompleteCard> createState() => _CompleteCardState();
}

class _CompleteCardState extends State<_CompleteCard> {
  final TextEditingController _workDone = TextEditingController();
  final TextEditingController _discount = TextEditingController();

  @override
  void dispose() {
    _workDone.dispose();
    _discount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ServiceDetailsController controller =
        Get.find<ServiceDetailsController>();

    return AppPermissionView(
      permission: AppPermissions.serviceComplete,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Complete and invoice',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            AppSpacing.gapXs,
            Text(
              'Totals the chargeable lines, consumes a free-service '
              'entitlement if this visit qualifies, raises the invoice and '
              'schedules the next visit.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppSpacing.gapLg,
            AppTextField.multiline(
              label: 'Work done',
              controller: _workDone,
              maxLines: 3,
              hint: 'What the workshop actually did',
            ),
            AppSpacing.gapLg,
            AppFieldRow(
              children: <Widget>[
                AppTextField.money(
                  label: 'Additional discount',
                  controller: _discount,
                  isRequired: false,
                ),
                const SizedBox.shrink(),
              ],
            ),
            AppSpacing.gapLg,
            Row(
              children: <Widget>[
                const Spacer(),
                Obx(
                  () => AppButton.primary(
                    label: 'Complete service',
                    size: AppButtonSize.large,
                    isLoading: controller.isSaving.value,
                    onPressed: () => controller.complete(
                      additionalDiscount:
                          double.tryParse(_discount.text.trim()) ?? 0,
                      workDone: _workDone.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          width: 130,
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
