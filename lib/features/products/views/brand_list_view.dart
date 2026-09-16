import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/common/widgets/app_text_field.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/features/products/controllers/brand_controller.dart';
import 'package:bike_showroom_management_system/features/products/models/brand_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Manufacturer list.
///
/// A brand is one editable field, so it is created and renamed in a dialog
/// rather than on its own route — pushing a full page to collect a single
/// name would be more navigation than the task deserves.
class BrandListView extends GetView<BrandController> {
  const BrandListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Brands',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.productsCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Brand',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => showBrandEditor(controller),
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
              width: 360,
              child: AppSearchField(
                hint: 'Search brands',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<BrandModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No brands yet',
                        message:
                            'Add the manufacturers you sell before creating '
                            'products.',
                        icon: Icons.sell_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<BrandModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, BrandModel brand) =>
                                _BrandCard(brand: brand),
                        columns: <AppDataColumn<BrandModel>>[
                          AppDataColumn<BrandModel>(
                            label: 'Brand',
                            sortKey: 'name',
                            cellBuilder: (_, BrandModel b) => Text(b.name),
                          ),
                          AppDataColumn<BrandModel>(
                            label: 'Status',
                            cellBuilder: (_, BrandModel b) =>
                                AppStatusChip(status: b.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, BrandModel b) =>
                                _RowActions(brand: b),
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
    floatingActionButton: context.isCompact
        ? AppPermissionView(
            permission: AppPermissions.productsCreate,
            child: FloatingActionButton(
              onPressed: () => showBrandEditor(controller),
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );
}

/// Opens the create/rename dialog. Public so the product form can offer
/// "add a brand" without navigating away from a half-filled form.
Future<void> showBrandEditor(
  BrandController controller, {
  BrandModel? existing,
}) => Get.dialog<void>(
  _BrandEditorDialog(controller: controller, existing: existing),
  barrierDismissible: false,
);

class _BrandEditorDialog extends StatefulWidget {
  const _BrandEditorDialog({required this.controller, this.existing});

  final BrandController controller;
  final BrandModel? existing;

  @override
  State<_BrandEditorDialog> createState() => _BrandEditorDialogState();
}

class _BrandEditorDialogState extends State<_BrandEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool saved = await widget.controller.save(
      name: _name.text,
      existing: widget.existing,
    );
    if (saved) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add Brand' : 'Rename Brand'),
    content: SizedBox(
      width: 360,
      child: AppTextField(
        label: 'Brand name',
        controller: _name,
        isRequired: true,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _save(),
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
  const _RowActions({required this.brand});

  final BrandModel brand;

  @override
  Widget build(BuildContext context) {
    final BrandController controller = Get.find<BrandController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.productsEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Rename',
            onPressed: () => showBrandEditor(controller, existing: brand),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.productsEdit,
          child: AppIconButton(
            icon: brand.isActive ? Icons.toggle_on : Icons.toggle_off_outlined,
            tooltip: brand.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => controller.toggleStatus(brand),
          ),
        ),
      ],
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.brand});

  final BrandModel brand;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  brand.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AppStatusChip(status: brand.status.value),
            ],
          ),
        ),
        _RowActions(brand: brand),
      ],
    ),
  );
}
