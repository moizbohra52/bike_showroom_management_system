import 'package:bike_showroom_management_system/common/layouts/app_shell.dart';
import 'package:bike_showroom_management_system/common/widgets/app_button.dart';
import 'package:bike_showroom_management_system/common/widgets/app_card.dart';
import 'package:bike_showroom_management_system/common/widgets/app_data_table.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dialog.dart';
import 'package:bike_showroom_management_system/common/widgets/app_dropdown.dart';
import 'package:bike_showroom_management_system/common/widgets/app_pagination.dart';
import 'package:bike_showroom_management_system/common/widgets/app_permission_view.dart';
import 'package:bike_showroom_management_system/common/widgets/app_responsive_layout.dart';
import 'package:bike_showroom_management_system/common/widgets/app_search_field.dart';
import 'package:bike_showroom_management_system/common/widgets/app_state_views.dart';
import 'package:bike_showroom_management_system/common/widgets/app_status_chip.dart';
import 'package:bike_showroom_management_system/config/theme_config.dart';
import 'package:bike_showroom_management_system/core/constants/permission_constants.dart';
import 'package:bike_showroom_management_system/core/enums/app_enums.dart';
import 'package:bike_showroom_management_system/features/products/controllers/product_controller.dart';
import 'package:bike_showroom_management_system/features/products/models/product_color_model.dart';
import 'package:bike_showroom_management_system/features/products/models/product_model.dart';
import 'package:bike_showroom_management_system/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The product catalogue: every model the group sells, shared across branches.
class ProductListView extends GetView<ProductController> {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Products',
    actions: <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: AppButton.ghost(
          label: 'Brands',
          icon: Icons.sell_outlined,
          size: AppButtonSize.small,
          onPressed: () => Get.toNamed(AppRoutes.brands),
        ),
      ),
      AppPermissionView(
        permission: AppPermissions.productsCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Product',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => _openForm(),
          ),
        ),
      ),
    ],
    body: AppContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: _Filters(),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<ProductModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: controller.params.value.hasActiveFilters
                    ? AppEmptyState.filtered(onAction: controller.clearFilters)
                    : const AppEmptyState(
                        title: 'No products yet',
                        message:
                            'Add the models you sell. Stock is recorded '
                            'separately, under Inventory.',
                        icon: Icons.two_wheeler_outlined,
                      ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<ProductModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        onRowTap: _openForm,
                        mobileCardBuilder:
                            (BuildContext context, ProductModel p) =>
                                _ProductCard(product: p),
                        columns: <AppDataColumn<ProductModel>>[
                          AppDataColumn<ProductModel>(
                            label: 'Product',
                            sortKey: 'name',
                            cellBuilder: (_, ProductModel p) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(p.displayName),
                                if (p.specSummary.isNotEmpty)
                                  Text(
                                    p.specSummary,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          AppDataColumn<ProductModel>(
                            label: 'Category',
                            sortKey: 'category',
                            cellBuilder: (_, ProductModel p) =>
                                Text(p.category.label),
                          ),
                          AppDataColumn<ProductModel>(
                            label: 'Colours',
                            cellBuilder: (_, ProductModel p) =>
                                _ColorSwatches(colors: p.activeColors),
                          ),
                          AppDataColumn<ProductModel>(
                            label: 'Price',
                            sortKey: 'selling_price',
                            numeric: true,
                            cellBuilder: (_, ProductModel p) =>
                                Text(p.formattedSellingPrice),
                          ),
                          AppDataColumn<ProductModel>(
                            label: 'Status',
                            cellBuilder: (_, ProductModel p) =>
                                AppStatusChip(status: p.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, ProductModel p) =>
                                _RowActions(product: p),
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
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            ),
          )
        : null,
  );

  /// Opens the form and reloads when it reports a save, so the list reflects
  /// the change without a manual refresh.
  static Future<void> _openForm([ProductModel? product]) async {
    final Object? result = await Get.toNamed(
      AppRoutes.productForm,
      arguments: product,
    );
    if (result is ProductModel) {
      await Get.find<ProductController>().reload();
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final ProductController controller = Get.find<ProductController>();
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 320,
          child: AppSearchField(
            hint: 'Search by name, model or HSN code',
            onChanged: controller.search,
          ),
        ),
        SizedBox(
          width: 240,
          child: Obx(
            () => AppDropdown<ProductCategory>(
              label: 'Category',
              hint: 'All categories',
              items: ProductCategory.values,
              itemLabel: (ProductCategory c) => c.label,
              value: controller.categoryFilter.value,
              onChanged: controller.filterByCategory,
            ),
          ),
        ),
      ],
    );
  }
}

/// Up to four colour dots, then a `+n` overflow. A model can have a dozen
/// colours and the cell has room for a handful.
class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.colors});

  final List<ProductColorModel> colors;

  static const int _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const Text('-');
    }
    final List<ProductColorModel> shown = colors.take(_maxShown).toList();
    final int hidden = colors.length - shown.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ProductColorModel color in shown)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Tooltip(
              message: color.colorName,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color.swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          ),
        if (hidden > 0)
          Text('+$hidden', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final ProductController controller = Get.find<ProductController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.productsEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () => ProductListView._openForm(product),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.productsEdit,
          child: AppIconButton(
            icon: product.isActive
                ? Icons.toggle_on
                : Icons.toggle_off_outlined,
            tooltip: product.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => controller.toggleStatus(product),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.productsDelete,
          child: AppIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            isDestructive: true,
            onPressed: () async {
              final bool confirmed = await AppDialog.confirm(
                title: 'Remove product?',
                message:
                    '${product.displayName} will be hidden from the '
                    'catalogue. Stock and past sales that reference it are '
                    'kept.',
                confirmLabel: 'Remove',
                isDestructive: true,
              );
              if (confirmed) {
                await controller.deleteProduct(product);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => ProductListView._openForm(product),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                product.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            AppStatusChip(status: product.status.value),
          ],
        ),
        AppSpacing.gapXs,
        Text(
          product.specSummary.isEmpty
              ? product.category.label
              : '${product.category.label} - ${product.specSummary}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppSpacing.gapSm,
        Row(
          children: <Widget>[
            Text(
              product.formattedSellingPrice,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            _ColorSwatches(colors: product.activeColors),
          ],
        ),
      ],
    ),
  );
}
