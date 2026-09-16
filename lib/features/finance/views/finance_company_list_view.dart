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
import 'package:bike_showroom_management_system/features/finance/controllers/finance_controller.dart';
import 'package:bike_showroom_management_system/features/finance/models/finance_company_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Financiers the showroom places loans with.
class FinanceCompanyListView extends GetView<FinanceCompanyController> {
  const FinanceCompanyListView({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'Finance Companies',
    actions: <Widget>[
      AppPermissionView(
        permission: AppPermissions.financeCreate,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: AppButton.primary(
            label: 'Add Company',
            icon: Icons.add,
            size: AppButtonSize.small,
            onPressed: () => showFinanceCompanyEditor(controller),
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
                hint: 'Search by name, code or contact',
                onChanged: controller.search,
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => AppAsyncBuilder<FinanceCompanyModel>(
                isLoading: controller.isLoading.value,
                error: controller.error.value,
                isEmpty: controller.response.value.isEmpty,
                hasData: controller.response.value.isNotEmpty,
                onRetry: controller.reload,
                emptyState: const AppEmptyState(
                  title: 'No finance companies yet',
                  message:
                      'Add the financiers you work with before booking a '
                      'financed sale.',
                  icon: Icons.account_balance_outlined,
                ),
                builder: (BuildContext context) => Column(
                  children: <Widget>[
                    Expanded(
                      child: AppDataTable<FinanceCompanyModel>(
                        items: controller.response.value.items,
                        sorts: controller.params.value.sorts,
                        onSort: controller.sortBy,
                        mobileCardBuilder:
                            (BuildContext context, FinanceCompanyModel c) =>
                                _CompanyCard(company: c),
                        columns: <AppDataColumn<FinanceCompanyModel>>[
                          AppDataColumn<FinanceCompanyModel>(
                            label: 'Code',
                            sortKey: 'code',
                            cellBuilder: (_, FinanceCompanyModel c) =>
                                Text(c.code),
                          ),
                          AppDataColumn<FinanceCompanyModel>(
                            label: 'Name',
                            sortKey: 'name',
                            cellBuilder: (_, FinanceCompanyModel c) =>
                                Text(c.name),
                          ),
                          AppDataColumn<FinanceCompanyModel>(
                            label: 'Contact',
                            cellBuilder: (_, FinanceCompanyModel c) =>
                                Text(c.contactPerson ?? '-'),
                          ),
                          AppDataColumn<FinanceCompanyModel>(
                            label: 'Phone',
                            cellBuilder: (_, FinanceCompanyModel c) =>
                                Text(c.phone ?? '-'),
                          ),
                          AppDataColumn<FinanceCompanyModel>(
                            label: 'Status',
                            cellBuilder: (_, FinanceCompanyModel c) =>
                                AppStatusChip(status: c.status.value),
                          ),
                        ],
                        rowActionsBuilder:
                            (BuildContext context, FinanceCompanyModel c) =>
                                _RowActions(company: c),
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

/// Opens the create/edit dialog. A financier is two fields, which is less than
/// a dedicated route is worth.
Future<void> showFinanceCompanyEditor(
  FinanceCompanyController controller, {
  FinanceCompanyModel? existing,
}) => Get.dialog<void>(
  _CompanyDialog(controller: controller, existing: existing),
  barrierDismissible: false,
);

class _CompanyDialog extends StatefulWidget {
  const _CompanyDialog({required this.controller, this.existing});

  final FinanceCompanyController controller;
  final FinanceCompanyModel? existing;

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bool saved = await widget.controller.save(
      name: _name.text,
      code: _code.text,
      existing: widget.existing,
    );
    if (saved) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Add Finance Company' : 'Edit Finance Company',
    ),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            label: 'Name',
            controller: _name,
            isRequired: true,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          AppSpacing.gapLg,
          AppTextField.code(
            label: 'Short code',
            controller: _code,
            hint: 'e.g. HDFC',
            maxLength: 20,
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
  const _RowActions({required this.company});

  final FinanceCompanyModel company;

  @override
  Widget build(BuildContext context) {
    final FinanceCompanyController controller =
        Get.find<FinanceCompanyController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppPermissionView(
          permission: AppPermissions.financeEdit,
          child: AppIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            onPressed: () =>
                showFinanceCompanyEditor(controller, existing: company),
          ),
        ),
        AppPermissionView(
          permission: AppPermissions.financeEdit,
          child: AppIconButton(
            icon: company.isActive
                ? Icons.toggle_on
                : Icons.toggle_off_outlined,
            tooltip: company.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => controller.toggleStatus(company),
          ),
        ),
      ],
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company});

  final FinanceCompanyModel company;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      company.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AppStatusChip(status: company.status.value),
                ],
              ),
              AppSpacing.gapXs,
              Text(company.code, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        _RowActions(company: company),
      ],
    ),
  );
}
