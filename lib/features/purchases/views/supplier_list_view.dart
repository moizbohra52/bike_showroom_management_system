import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_field_row.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/features/purchases/controllers/supplier_controller.dart';
import 'package:bike_showroom_management_system/features/purchases/models/supplier_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Suppliers the group buys from. Shared across branches.
class SupplierListView extends GetView<SupplierController> {
  const SupplierListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Suppliers',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.suppliersCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Supplier',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => showSupplierEditor(controller),
          ),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: SizedBox(
              width: 380,
              child: AppSearchField(
                hint: 'Search by name, code, phone or GSTIN',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<SupplierModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: const AppEmptyState(
                  title: 'No suppliers yet',
                  message:
                      'Add the distributors you buy from before raising a '
                      'purchase order.',
                  icon: Icons.local_shipping_outlined,
                ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<SupplierModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, SupplierModel s) =>
                                _SupplierCard(supplier: s),
                        columns: <AppDataColumn<SupplierModel>>[
                          AppDataColumn<SupplierModel>(
                            label: 'Name',
                            sortKey: 'name',
                            cellBuilder: (_, SupplierModel s) => Text(s.name),
                          ),
                          AppDataColumn<SupplierModel>(
                            label: 'Code',
                            sortKey: 'code',
                            cellBuilder: (_, SupplierModel s) =>
                                Text(s.code ?? '-'),
                          ),
                          AppDataColumn<SupplierModel>(
                            label: 'Phone',
                            cellBuilder: (_, SupplierModel s) =>
                                Text(s.phone ?? '-'),
                          ),
                          AppDataColumn<SupplierModel>(
                            label: 'GSTIN',
                            cellBuilder: (_, SupplierModel s) =>
                                Text(s.gstNumber ?? '-'),
                          ),
                          AppDataColumn<SupplierModel>(
                            label: 'City',
                            cellBuilder: (_, SupplierModel s) =>
                                Text(s.city ?? '-'),
                          ),
                          AppDataColumn<SupplierModel>(
                            label: 'Status',
                            cellBuilder: (_, SupplierModel s) =>
                                AppStatusChip(status: s.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, SupplierModel s) =>
                                _RowActions(supplier: s),
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

/// Opens the create/edit dialog.
Future<void> showSupplierEditor(
  SupplierController controller, {
  SupplierModel? existing,
}) => Get.dialog<void>(
  _SupplierDialog(controller: controller, existing: existing),
  barrierDismissible: false,
);

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog({required this.controller, this.existing});

  final SupplierController controller;
  final SupplierModel? existing;

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.existing?.phone ?? '',
  );
  late final TextEditingController _gst = TextEditingController(
    text: widget.existing?.gstNumber ?? '',
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.existing?.city ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _phone.dispose();
    _gst.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool saved = await widget.controller.save(
      name: _name.text,
      code: _code.text,
      phone: _phone.text,
      gstNumber: _gst.text,
      city: _city.text,
      existing: widget.existing,
    );
    if (saved) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add Supplier' : 'Edit Supplier'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppFieldRow(
            children: <Widget>[
              AppTextField(
                label: 'Name',
                controller: _name,
                isRequired: true,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              AppTextField.code(
                label: 'Code',
                controller: _code,
                isRequired: false,
                maxLength: 20,
              ),
            ],
          ),
          AppSpacing.gapLg,
          AppFieldRow(
            children: <Widget>[
              AppTextField.phone(
                label: 'Phone',
                controller: _phone,
                isRequired: false,
              ),
              AppTextField(label: 'City', controller: _city),
            ],
          ),
          AppSpacing.gapLg,
          AppTextField.code(
            label: 'GSTIN',
            controller: _gst,
            isRequired: false,
            maxLength: 15,
            // Needed to claim input tax credit on what this supplier bills.
            helper: 'Required to claim input tax credit',
          ),
        ],
      ),
    ),
    actions: <Widget>[
      AppButton.ghost(label: 'Cancel', onPressed: Get.back<void>),
      Obx(
        () => AppButton.primary(
          label: widget.existing == null ? 'Add' : 'Save',
          isLoading: widget.controller.isSaving.value,
          onPressed: _save,
        ),
      ),
    ],
  );
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.supplier});

  final SupplierModel supplier;

  @override
  Widget build(BuildContext context) {
    final SupplierController controller = Get.find<SupplierController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.suppliersEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => showSupplierEditor(controller, existing: supplier),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.suppliersEdit,
          child: AppIconButton(
            icon: supplier.isActive
                ? Icons.toggle_on
                : Icons.toggle_off_outlined,
            tooltip: supplier.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => controller.toggleStatus(supplier),
          ),
        ),
      ],
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier});

  final SupplierModel supplier;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                supplier.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: supplier.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          <String>[
            if (supplier.code != null) supplier.code!,
            if (supplier.phone != null) supplier.phone!,
            if (supplier.city != null) supplier.city!,
          ].join(' - '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                supplier.gstNumber ?? 'No GSTIN',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _RowActions(supplier: supplier),
          ],
        ),
      ],
    ),
  );
}
